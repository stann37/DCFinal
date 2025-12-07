import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Read the CSV file
df = pd.read_csv('tremolo_output.csv')

# Create figure with subplots
fig, axes = plt.subplots(3, 1, figsize=(14, 10))

# Plot 1: Input and Output signals
axes[0].plot(df['sample'], df['input'], label='Input (Ramp)', alpha=0.7, linewidth=0.5)
axes[0].plot(df['sample'], df['output'], label='Output (Tremolo Applied)', alpha=0.7, linewidth=0.5)
axes[0].set_xlabel('Sample Number')
axes[0].set_ylabel('Amplitude')
axes[0].set_title('Tremolo Effect: Input vs Output')
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# Plot 2: Triangle wave (LFO)
axes[1].plot(df['sample'], df['tri_wave'], label='Triangle LFO', color='green', linewidth=1)
axes[1].set_xlabel('Sample Number')
axes[1].set_ylabel('LFO Amplitude')
axes[1].set_title('Triangle Wave LFO (Low Frequency Oscillator)')
axes[1].legend()
axes[1].grid(True, alpha=0.3)

# Plot 3: Output only (zoomed view)
# Show a smaller section to see the tremolo effect clearly
zoom_start = len(df) // 4
zoom_end = zoom_start + 10000
axes[2].plot(df['sample'][zoom_start:zoom_end], df['output'][zoom_start:zoom_end], 
             label='Output (Zoomed)', color='red', linewidth=0.8)
axes[2].set_xlabel('Sample Number')
axes[2].set_ylabel('Amplitude')
axes[2].set_title('Tremolo Output (Zoomed View)')
axes[2].legend()
axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('tremolo_analysis.png', dpi=300, bbox_inches='tight')
print("Plot saved as 'tremolo_analysis.png'")
plt.show()

# Print some statistics
print("\n=== Tremolo Analysis ===")
print(f"Total samples: {len(df)}")
print(f"Input range: [{df['input'].min()}, {df['input'].max()}]")
print(f"Output range: [{df['output'].min()}, {df['output'].max()}]")
print(f"Triangle wave range: [{df['tri_wave'].min()}, {df['tri_wave'].max()}]")

# Calculate modulation depth
if len(df) > 0:
    # Find peaks in a section of output
    section = df['output'][10000:20000]
    max_val = section.max()
    min_val = section.min()
    modulation_depth = ((max_val - min_val) / (max_val + min_val)) * 100 if (max_val + min_val) != 0 else 0
    print(f"Estimated modulation depth: {modulation_depth:.2f}%")