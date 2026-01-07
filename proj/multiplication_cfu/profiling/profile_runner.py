#!/usr/bin/env python3
"""
Automated profiling workflow runner for CFU Playground.
Executes 'make load', captures output, and auto-generates analysis.

Usage:
    python3 profiling/profile_runner.py
    
    Then navigate the menu interactively:
    - Select model number
    - Select 'g' for golden tests
    
    Script automatically:
    - Captures output (only from Liftoff onwards)
    - Extracts model name
    - Saves to profiling/archive/<commit_hash>/
    - Runs profile_layers.py for analysis and visualization
"""

import subprocess
import sys
import time
import re
from pathlib import Path
from datetime import datetime

def get_git_commit():
    """Get current git commit hash (short form)"""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--short', 'HEAD'],
            cwd=Path(__file__).parent.parent.parent,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    return 'unknown'

def extract_model_name(output_text):
    """Extract model name from output. Format: 'Tests for <model> model'"""
    match = re.search(r'Tests for (\w+) model', output_text)
    if match:
        return match.group(1)
    return None

def run_make_load_with_capture(output_dir=None):
    """
    Run 'make load' and capture output to file using tee.
    - Only saves output from "Liftoff" onwards
    - Extracts model name
    - Saves to profiling/archive/<commit_hash>/
    - Monitors for 'Golden tests passed' to auto-terminate
    
    Args:
        output_dir: Directory to save output (default: profiling/archive/<commit_hash>/)
    
    Returns:
        Tuple of (output_file_path, model_name)
    """
    # Determine output directory (profiling/archive/<commit_hash>/)
    if output_dir is None:
        git_commit = get_git_commit()
        archive_dir = Path(__file__).parent / 'archive' / git_commit
    else:
        archive_dir = Path(output_dir)
    
    archive_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"\n{'='*70}")
    print("Starting 'make load' with output capture")
    print(f"{'='*70}")
    print(f"Output will be saved to: {archive_dir}/")
    print("\nNavigate the menu:")
    print("  1. Select model number")
    print("  2. Press 'g' for golden tests")
    print("  3. Wait for completion (auto-detects 'Golden tests passed')")
    print(f"{'='*70}\n")
    
    # Create temporary file to capture everything
    temp_file = Path(f"/tmp/cfu_profile_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    
    # Run make load with tee in background
    # Only capture stdout (not stderr with build logs)
    cmd = f"make load 2>/dev/null | tee {temp_file}"
    
    proc = subprocess.Popen(
        cmd,
        shell=True,
        cwd=Path(__file__).parent.parent
    )
    
    # Monitor output file for completion
    model_name = None
    
    try:
        last_pos = 0
        while proc.poll() is None:  # While process is running
            time.sleep(0.2)
            
            # Read new content from file
            try:
                with open(temp_file, 'r', encoding='utf-8', errors='ignore') as f:
                    f.seek(last_pos)
                    new_content = f.read()
                    last_pos = f.tell()
                    
                    # Extract model name if found
                    if model_name is None:
                        extracted = extract_model_name(new_content)
                        if extracted:
                            model_name = extracted
                    
                    # Check for golden tests completion
                    if 'Golden tests passed' in new_content:
                        print("\n[Auto-detected: Golden tests passed - terminating in 2s]")
                        time.sleep(2)  # Give it time to flush remaining output
                        proc.terminate()
                        break
            except:
                pass
    
    except KeyboardInterrupt:
        print("\n\n[Terminated by user]")
        proc.terminate()
    
    # Wait for process to finish
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
    
    # Give terminal a moment to settle, then do full reset
    time.sleep(0.3)
    subprocess.run('reset 2>/dev/null', shell=True)
    
    # Now process the temp file: only keep content from Liftoff onwards
    if temp_file.exists():
        with open(temp_file, 'r', encoding='utf-8', errors='ignore') as f:
            full_content = f.read()
        
        # Find Liftoff position (use the LAST occurrence, not first)
        # Note: Liftoff line has ANSI escape codes like [1mLiftoff![0m
        liftoff_idx = full_content.rfind('Liftoff!')
        
        if liftoff_idx >= 0:
            # Find start of line containing Liftoff
            line_start = full_content.rfind('\n', 0, liftoff_idx)
            if line_start >= 0:
                filtered_content = full_content[line_start + 1:]
            else:
                filtered_content = full_content[liftoff_idx:]
        else:
            filtered_content = full_content
        
        # If model name not found, try again from filtered content
        if model_name is None:
            model_name = extract_model_name(filtered_content)
        
        # Generate output filename with model name
        if model_name:
            output_filename = f"profile_{model_name}.txt"
        else:
            output_filename = f"profile_unknown.txt"
        
        output_file = archive_dir / output_filename
        
        # Write filtered content
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(filtered_content)
        
        # Clean up temp file
        temp_file.unlink()
        
        print(f"\nSaved output: {output_file}")
        
        # Verify output file has content
        if output_file.stat().st_size == 0:
            print(f"\nError: Output file is empty: {output_file}")
            sys.exit(1)
        
        return output_file, model_name
    else:
        print(f"\nError: Could not capture output")
        sys.exit(1)

def analyze_profiling(input_file):
    """
    Run profile_layers.py as subprocess to analyze profiling data.
    
    Args:
        input_file: Path to saved profiling output
    """
    result = subprocess.run(
        [sys.executable, str(Path(__file__).parent / 'profile_layers.py'), str(input_file)],
        capture_output=False
    )
    return result.returncode == 0

def main():
    # Run make load and capture output
    output_file, model_name = run_make_load_with_capture()
    
    print(f"\n{'='*70}")
    print("Analyzing profiling data...")
    print(f"{'='*70}\n")
    
    # Analyze and visualize
    try:
        success = analyze_profiling(output_file)
        if success:
            print(f"\n{'='*70}")
            print("Profiling complete!")
            print(f"{'='*70}")
            print(f"\nGenerated files:")
            stem = output_file.stem
            profiling_dir = output_file.parent
            print(f"  Raw output: {output_file}")
            print(f"  CSV data:   {profiling_dir / (stem + '.csv')}")
            print(f"  Plot:       {profiling_dir / (stem + '.png')}")
            print(f"\nModel: {model_name if model_name else 'Unknown'}")
            print(f"Commit: {get_git_commit()}")
        else:
            raise Exception("profile_layers.py returned non-zero exit code")
    except Exception as e:
        print(f"\n{'='*70}")
        print(f"Error during analysis: {e}")
        print(f"{'='*70}")
        print(f"Raw data saved to: {output_file}")
        print("You can manually analyze it with:")
        print(f"  python3 profiling/profile_layers.py {output_file}")
        print()
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
