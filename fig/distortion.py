import numpy as np
import matplotlib.pyplot as plt
import os


def custom_distortion(x, thresholds):
    if x < 0:
        abs_x = -x
        is_negative = True
    else:
        abs_x = x
        is_negative = False
    
    # distortion logic
    dist = thresholds
    
    if abs_x >= dist[6]:
        if abs_x >= dist[3]:
            if abs_x >= dist[1]:
                if abs_x >= dist[0]:
                    result_abs = dist[0]
                else:
                    result_abs = dist[1]
            else:
                if abs_x >= dist[2]:
                    result_abs = dist[2]
                else:
                    result_abs = dist[3]
        else:
            if abs_x >= dist[5]:
                if abs_x >= dist[4]:
                    result_abs = dist[4]
                else:
                    result_abs = dist[5]
            else:
                result_abs = dist[6]
    else:
        if abs_x >= dist[9]:
            if abs_x >= dist[8]:
                if abs_x >= dist[7]:
                    result_abs = dist[7]
                else:
                    result_abs = dist[8]
            else:
                result_abs = dist[9]
        else:
            if abs_x >= dist[10]:
                result_abs = dist[10]
            elif abs_x >= dist[11]:
                result_abs = dist[11]
            else:
                result_abs = abs_x
    
    if is_negative:
        y = -result_abs
    else:
        y = result_abs
    
    return y

output_folder = 'outputs'

if not os.path.exists(output_folder):
    os.makedirs(output_folder)

thresholds = [0.8 - i * 0.05 for i in range(12)]

# print("threshold setting:")
# for i, thresh in enumerate(thresholds):
#     print(f"  dist[{i:2d}] = {thresh:.2f}")

x = np.linspace(-1, 1, 2000)
y = np.array([custom_distortion(xi, thresholds) for xi in x])

plt.figure(figsize=(10, 8))

plt.plot(x, y, 'b-', linewidth=2.5, label='Distortion Effect')
plt.plot(x, x, 'r--', linewidth=1.5, alpha=0.5, label='Linear (y=x)')

plt.xlabel('Input (x)', fontsize=14)
plt.ylabel('Output (y)', fontsize=14)
plt.title('Distortion Transfer Curve', fontsize=16, fontweight='bold')
plt.grid(True, alpha=0.3)
plt.legend(fontsize=12)
plt.xlim([-1, 1])
plt.ylim([-1, 1])
plt.axhline(y=0, color='k', linewidth=0.8)
plt.axvline(x=0, color='k', linewidth=0.8)

plt.tight_layout()

# save figure
output_path = os.path.join(output_folder, 'distortion_transfer_curve.png')
plt.savefig(output_path, dpi=200, bbox_inches='tight')
print("\nsaved: distortion_transfer_curve.png")
plt.show()

t = np.linspace(0, 2, 1000)  
frequency = 1

sine_wave = np.sin(2 * np.pi * frequency * t)

distorted_wave = np.array([custom_distortion(amp, thresholds) for amp in sine_wave])

plt.figure(figsize=(14, 6))

plt.plot(t, sine_wave, 'b-', linewidth=2, label='sine wave', alpha=0.7)
plt.plot(t, distorted_wave, 'r-', linewidth=2, label='distorted sine wave')

plt.xlabel('t', fontsize=14)
plt.ylabel('amplitude', fontsize=14)
plt.title('Distortion effect', fontsize=16, fontweight='bold')
plt.grid(True, alpha=0.3, linestyle='--')
plt.legend(fontsize=12, loc='upper right')
plt.axhline(y=0, color='k', linewidth=0.8)

plt.axhline(y=0.8, color='g', linewidth=1, linestyle=':', alpha=0.5, label='threshold (±0.8)')
plt.axhline(y=-0.8, color='g', linewidth=1, linestyle=':', alpha=0.5)

plt.ylim([-1.1, 1.1])
plt.tight_layout()

# save figure
output_path = os.path.join(output_folder, 'sine_wave_distortion.png')
plt.savefig(output_path, dpi=200, bbox_inches='tight')
print(f"saved: {output_path}")

plt.show()