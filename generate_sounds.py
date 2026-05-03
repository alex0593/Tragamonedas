import wave
import math
import struct
import os

def generate_clean_tick(freq, duration_ms, volume=0.5, sample_rate=44100):
    # Generamos un sonido MUY limpio y corto para evitar ruido a altas velocidades
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    samples = []
    
    attack_samples = int(sample_rate * 0.005) # 5ms attack
    
    for i in range(num_samples):
        t = i / sample_rate
        
        # Onda Triangular (suena a Nintendo/GameBoy clásico, muy limpio)
        tr = (2.0 / math.pi) * math.asin(math.sin(2 * math.pi * freq * t))
        
        # Envolvente ADSR limpia para evitar "pops" o "clicks"
        if i < attack_samples:
            env = i / attack_samples # Fade in
        else:
            # Fade out exponencial suave
            env = math.exp(-4.0 * (i - attack_samples) / num_samples)
            
        # Asegurar que termine en 0 absoluto
        if i > num_samples - 100:
            env *= (num_samples - i) / 100.0
            
        main_val = tr * env
        
        sample = int(32767 * main_val * volume)
        sample = max(-32768, min(32767, sample))
        samples.append(sample)
        
    return samples

output_dir = "assets/sounds"
os.makedirs(output_dir, exist_ok=True)

# E4 = 329.63 Hz (+2 Tonos desde C4)
root_freq = 329.63 
ratios = [1.0, 1.125, 1.25, 1.5, 1.66, 2.0, 2.25, 2.5, 3.0, 3.33]

# 1. Escala Pentatónica (Duración de 40ms, sin ecos)
for i, ratio in enumerate(ratios):
    samples = generate_clean_tick(root_freq * ratio, duration_ms=40, volume=0.45)
    path = os.path.join(output_dir, f"pentatonic_{i}.wav")
    with wave.open(path, 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(44100)
        for s in samples: f.writeframesraw(struct.pack('<h', s))
    print(f"Generated clean {path}")

# 2. Arpegio Bet Sound
bet_ratios = [2.0, 1.5, 1.33, 1.0]
bet_samples = []
for r in bet_ratios:
    note = generate_clean_tick(root_freq * r, duration_ms=35, volume=0.5)
    bet_samples.extend(note)

path = os.path.join(output_dir, "vintage_bet.wav")
with wave.open(path, 'wb') as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(44100)
    for s in bet_samples: f.writeframesraw(struct.pack('<h', s))
print("Generated clean vintage_bet.wav")
