#!/usr/bin/env python3
"""
Reads and parses profiling output from CFU Playground golden tests,
creates diagrams and visualizations.
"""

import re
import sys
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

class LayerProfiler:
    def __init__(self):
        self.layers = []
        self.total_cycles = 0
        self.total_ms = 0
        self.cycles_runs = []  # Cycles per run (end-to-end)
        self.runs = []  # Saves multiple runs for averaging
        
    def parse_output(self, text):
        """Parse test output and extract layer performance from multiple runs"""
        current_run = []
        cycles_list = []
        
        # Dismantle text into lines for processing
        lines = text.split('\n')
        
        for line in lines:
            line = line.strip()
            
            # CSV header indicates start of a new run
            if line == '"Event","Tag","Ticks"':
                # Flush previously collected run if any available
                if current_run:
                    self.runs.append(current_run)
                    current_run = []
            
            # CSV data lines "Event,Tag,Ticks"
            elif re.match(r'^\d+,[A-Z_0-9]+,\d+$', line):
                parts = line.split(',')
                event_id = int(parts[0])
                operation = parts[1]
                ticks = int(parts[2])
                current_run.append({
                    'id': event_id,
                    'operation': operation,
                    'ticks': ticks
                })
            
            # Detect end-to-end cycles line: "XXX ( YYYYY )  cycles total"
            elif 'cycles total' in line:
                match = re.search(r'\(\s*(\d+)\s*\)\s+cycles total', line)
                if match:
                    cycles = int(match.group(1))
                    cycles_list.append(cycles)
        
        # Save last run if exists
        if current_run:
            self.runs.append(current_run)
        
        # Store per-run cycles and compute average across runs
        if cycles_list:
            self.cycles_runs = cycles_list
            self.total_cycles = int(np.mean(cycles_list))
        
        # Runtime in ms assuming 50 MHz CPU
        CPU_FREQ_MHZ = 50 # TODO: make configurable
        self.total_ms = self.total_cycles / (CPU_FREQ_MHZ * 1e6)
    
    def parse_file(self, filename):
        """Reading and parsing of output file"""
        with open(filename, 'r') as f:
            self.parse_output(f.read())
        self.compute_average_runs()
    
    def compute_average_runs(self):
        """Average multiple runs into a single dataset"""
        if not self.runs:
            return
        
        # If multiple runs: average
        num_runs = len(self.runs)
        if num_runs > 1:
            print(f"\nAveraging {num_runs} golden tests...")
        
        # All runs share same structure -> average
        self.layers = []
        num_layers = len(self.runs[0])
        
        for layer_idx in range(num_layers):
            ids = [run[layer_idx]['id'] for run in self.runs]
            ops = [run[layer_idx]['operation'] for run in self.runs]
            ticks_list = [run[layer_idx]['ticks'] for run in self.runs]
            
            # Validate consistent IDs/ops across runs
            if len(set(ids)) == 1 and len(set(ops)) == 1:
                avg_ticks = np.mean(ticks_list)
                std_ticks = np.std(ticks_list)
                self.layers.append({
                    'id': ids[0],
                    'operation': ops[0],
                    'ticks': avg_ticks,
                    'std': std_ticks,
                    'ticks_list': ticks_list
                })
        
        if num_runs > 1:
            print(f"Averaged {len(self.layers)} layers")
    
    def get_dataframe(self):
        """Return layer data as DataFrame"""
        if not self.layers:
            return pd.DataFrame()
        return pd.DataFrame(self.layers)
    
    def print_summary(self):
        """Print a concise English summary"""
        if not self.layers:
            print("No layer data found!")
            return
        
        df = self.get_dataframe()
        total_ticks = df['ticks'].sum()
        
        print("\n" + "="*70)
        print("LAYER PROFILING SUMMARY")
        print("="*70)
        
        print(f"\nLayers: {len(df)}")
        print(f"Total ticks (layer-summed): {total_ticks:,}")
        print(f"End-to-end cycles (avg over runs): {self.total_cycles:,}")
        if self.total_ms > 0:
            print(f"End-to-end time (avg): {self.total_ms*1000:.3f} ms")
        if self.cycles_runs:
            CPU_FREQ_MHZ = 50 #TODO: make configurable
            runs_ms = [c / (CPU_FREQ_MHZ*1e6) * 1000.0 for c in self.cycles_runs]
            print("Runs (cycles/ms):")
            for i, c in enumerate(self.cycles_runs, start=1):
                print(f"  Run {i}: {c:,} cycles  |  {runs_ms[i-1]:.3f} ms")
        
        print(f"\nTop bottlenecks (by ticks):")
        print("-" * 70)
        print(f"{'ID':>3} {'Operation':<20} {'Ticks':>12} {'%':>8} {'Cumsum':>8}")
        print("-" * 70)
        
        # Sort by ticks to show largest contributors
        df_sorted = df.sort_values('ticks', ascending=False)
        cumsum = 0
        for _, row in df_sorted.iterrows():
            pct = (row['ticks'] / total_ticks) * 100
            cumsum += row['ticks']
            cumsum_pct = (cumsum / total_ticks) * 100
            print(f"{row['id']:3d} {row['operation']:<20} {row['ticks']:>12,} {pct:>7.1f}% {cumsum_pct:>7.1f}%")
        
        print("\n" + "="*70)
        
        # Group by operation type to see where time is spent
        print("\nOperation summary:")
        print("-" * 70)
        op_summary = df.groupby('operation')['ticks'].agg(['sum', 'count', 'mean']).sort_values('sum', ascending=False)
        print(f"{'Operation':<20} {'Total':>12} {'Count':>8} {'Average':>12}")
        print("-" * 70)
        for op, row in op_summary.iterrows():
            print(f"{op:<20} {row['sum']:>12,.0f} {row['count']:>8.0f} {row['mean']:>12,.0f}")
        
        print("\n" + "="*70 + "\n")
    
    def plot_summary(self, save_path=None, model_name=None):
        """Create visualizations of profiling data"""
        if not self.layers:
            print("No data to plot!")
            return
        
        df = self.get_dataframe()
        total_ticks = df['ticks'].sum()
        op_summary_series = df.groupby('operation')['ticks'].sum().sort_values(ascending=False)
        ops = op_summary_series.index.tolist()
        ops_vals = op_summary_series.values

        # Create plots 1x2
        fig, (ax1, ax3) = plt.subplots(1, 2, figsize=(16, 6))
        title = 'CFU Playground - Profiling Summary'
        if model_name:
            title += f' ({model_name})'
        fig.suptitle(title, fontsize=16, fontweight='bold')

        # Plot 1: Operation totals (bar)
        colors_bar = plt.cm.tab20c(np.linspace(0, 1, len(ops)))
        ax1.bar(range(len(ops)), ops_vals, color=colors_bar)
        ax1.set_xticks(range(len(ops)))
        ax1.set_xticklabels(ops, rotation=20, ha='right')
        ax1.set_ylabel('Ticks')
        ax1.set_title('Total ticks by operation (abs)')
        for i, v in enumerate(ops_vals):
            ax1.text(i, v, f"{v:,.0f}", ha='center', va='bottom', fontsize=9)
        ax1.grid(axis='y', alpha=0.3)

        # Plot 2: Pareto across operations
        cumulative = op_summary_series.cumsum()
        cumulative_pct = (cumulative / total_ticks) * 100
        ax3.plot(range(len(cumulative)), cumulative_pct, 'o-', linewidth=2, markersize=6)
        ax3.axhline(y=80, color='r', linestyle='--', label='80% threshold')
        ax3.set_xlabel('Operations (sorted by ticks)')
        ax3.set_ylabel('Cumulative % of total ticks')
        ax3.set_title('Pareto: where time is spent')
        ax3.set_xticks(range(len(ops)))
        ax3.set_xticklabels(ops, rotation=20, ha='right')
        ax3.grid(True, alpha=0.3)
        ax3.legend()
        ax3.set_ylim([0, 105])

        # Add time summary as a text box
        e2e_ms = self.total_ms * 1000.0 if self.total_ms else None
        # Calculate time spent in each operation
        by_op_ms = []
        if e2e_ms is not None:
            for op, ticks in op_summary_series.items():
                proportion = ticks / total_ticks
                op_time_ms = proportion * e2e_ms
                by_op_ms.append((op, op_time_ms))
        
        lines = []
        if e2e_ms is not None:
            lines.append(f"End-to-end avg: {e2e_ms:.2f} ms")
        else:
            lines.append("End-to-end avg: n/a")
        lines.append("By operation (total):")
        for op, ms in by_op_ms:
            lines.append(f"  • {op}: {ms:.2f} ms")
        summary_text = "\n".join(lines)
        ax3.text(
            0.98,
            0.02,
            summary_text,
            transform=ax3.transAxes,
            va='bottom',
            ha='right',
            fontsize=9,
            bbox=dict(facecolor='white', alpha=0.8, edgecolor='none')
        )
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"Saved: {save_path}")
        
        plt.show()


def main():
    if len(sys.argv) < 2:
        print("Usage: ./profile_layers.py <output.txt>")
        print("\nExample:")
        print("  python3 profile_layers.py output.txt")
        sys.exit(1)
    
    input_file = sys.argv[1]
    input_path = Path(input_file)
    
    if not input_path.exists():
        print(f"Error: {input_file} not found!")
        sys.exit(1)
    
    profiler = LayerProfiler()
    profiler.parse_file(input_file)
    profiler.print_summary()
    
    # Save plot in profiling folder
    profiling_dir = input_path.parent
    stem = input_path.stem
    output_png = profiling_dir / f"{stem}.png"
    
    # Extract model name from filename ("profile_pdti8" -> "pdti8")
    model_name = stem.replace("profile_", "") if stem.startswith("profile_") else stem
    
    profiler.plot_summary(save_path=str(output_png), model_name=model_name)


if __name__ == '__main__':
    main()
