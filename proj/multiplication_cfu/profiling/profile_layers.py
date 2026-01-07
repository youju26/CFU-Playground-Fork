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
        self.runs = []  # Saves multiple runs for averaging
        self.CYCLES_PER_TICK = 1024  # From official docs: 1 tick = 1024 cycles
        
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
            self.total_cycles = int(np.mean(cycles_list))
        
        # Runtime in ms assuming 50 MHz CPU
        CPU_FREQ_MHZ = 50 # TODO: make configurable
        self.total_ms = self.total_cycles / (CPU_FREQ_MHZ * 1e6)
    
    def parse_file(self, filename):
        """Reading and parsing of output file"""
        with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
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
                avg_cycles = avg_ticks * self.CYCLES_PER_TICK
                avg_ms = avg_cycles / (50e6) * 1000.0  # 50 MHz CPU
                self.layers.append({
                    'id': ids[0],
                    'operation': ops[0],
                    'ticks': avg_ticks,
                    'cycles': avg_cycles,
                    'ms': avg_ms,
                    'std': std_ticks
                })
        
        if num_runs > 1:
            print(f"Averaged {len(self.layers)} layers")
    
    def get_dataframe(self):
        """Return layer data as DataFrame"""
        if not self.layers:
            return pd.DataFrame()
        return pd.DataFrame(self.layers)

    def export_csv(self, save_path):
        """Export per-layer statistics and summary to CSV"""
        df = self.get_dataframe()
        if df.empty:
            print("No data to export!")
            return

        # Round numeric columns for readability
        df_out = df.copy()
        df_out['ticks'] = df_out['ticks'].round(0).astype(int)
        df_out['cycles'] = df_out['cycles'].round(0).astype(int)
        df_out['ms'] = df_out['ms'].round(3)
        df_out['std'] = df_out['std'].round(2)

        # Add empty end-to-end columns for layer rows
        df_out['end_to_end_cycles'] = ''
        df_out['end_to_end_ms'] = ''

        # Write CSV
        df_out.to_csv(save_path, index=False)
        print(f"Saved CSV: {save_path}")

    def print_summary(self):
        """Print a concise per-layer summary including cycles and ms"""
        df = self.get_dataframe()
        if df.empty:
            print("No layer data available.")
            return

        e2e_ms = self.total_ms * 1000.0 if self.total_ms else None
        if e2e_ms is not None:
            print(f"\nEnd-to-end: {self.total_cycles:,} cycles | {e2e_ms:.2f} ms")
        else:
            print(f"\nEnd-to-end: {self.total_cycles:,} cycles")

        # Header
        print("\nID  Operation                Cycles        ms     std")
        print("--  ----------------------  -----------  ------  ----")
        for _, row in df.sort_values('cycles', ascending=False).iterrows():
            rid = int(row['id'])
            op = str(row['operation'])[:22].ljust(22)
            cyc = int(round(row['cycles']))
            ms = float(row['ms'])
            std = f"{row['std']:.2f}"
            print(f"{rid:2d}  {op}  {cyc:11,d}  {ms:6.2f}  {std}")

    def plot_summary(self, save_path=None, model_name=None):
        """Create visualizations: per-layer bars and pie grouped by operation"""
        if not self.layers:
            print("No data to plot!")
            return

        df = self.get_dataframe()
        total_cycles = df['cycles'].sum()
        df_sorted = df.sort_values('cycles', ascending=False)

        # Create 1x2 subplot layout
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
        title = 'CFU Playground - Layer Profiling Summary'
        if model_name:
            title += f' ({model_name})'
        fig.suptitle(title, fontsize=16, fontweight='bold')

        # Plot 1: Layer cycles (all layers, sorted)
        layer_labels = [f"L{row['id']} {row['operation'][:15]}" for _, row in df_sorted.iterrows()]
        layer_cycles = df_sorted['cycles'].values
        colors_bar = plt.cm.tab20c(np.linspace(0, 1, len(layer_labels)))
        ax1.barh(range(len(layer_labels)), layer_cycles, color=colors_bar)
        ax1.set_yticks(range(len(layer_labels)))
        ax1.set_yticklabels(layer_labels, fontsize=9)
        ax1.set_xlabel('Cycles')
        ax1.set_title('Cycles per layer (sorted descending)')
        ax1.grid(axis='x', alpha=0.3)
        for i, (_, row) in enumerate(df_sorted.iterrows()):
            v = row['cycles']
            pct = (v / total_cycles) * 100
            ms = row.get('ms', 0)
            ax1.text(v, i, f" {v:,.0f} ({ms:.1f}ms, {pct:.1f}%)", va='center', fontsize=7)

        # Plot 2: Pie chart grouped by operation (layer type)
        op_summary_series = df.groupby('operation')['cycles'].sum().sort_values(ascending=False)
        ops = op_summary_series.index.tolist()
        op_vals = op_summary_series.values
        colors_pie = plt.cm.tab20c(np.linspace(0, 1, len(ops)))
        ax2.pie(op_vals, labels=ops, autopct='%1.1f%%', colors=colors_pie, startangle=90)
        ax2.set_title('Distribution by layer type (operation)')

        # Add summary info to plot
        e2e_ms = self.total_ms * 1000.0 if self.total_ms else None
        if e2e_ms is not None:
            summary_text = f"End-to-end: {self.total_cycles:,} cycles | {e2e_ms:.2f} ms\nTotal layers: {len(df)}"
        else:
            summary_text = f"End-to-end: {self.total_cycles:,} cycles\nTotal layers: {len(df)}"

        fig.text(0.5, 0.02, summary_text, ha='center', fontsize=11,
                 bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))

        plt.tight_layout(rect=[0, 0.03, 1, 0.96])

        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"Saved: {save_path}")


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
    output_csv = profiling_dir / f"{stem}.csv"
    
    # Extract model name from filename ("profile_pdti8" -> "pdti8")
    model_name = stem.replace("profile_", "") if stem.startswith("profile_") else stem
    
    profiler.plot_summary(save_path=str(output_png), model_name=model_name)
    profiler.export_csv(str(output_csv))


if __name__ == '__main__':
    main()
