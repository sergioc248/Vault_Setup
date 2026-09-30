#!/usr/bin/env python3
import hashlib


def modexp(base: int, exponent: int, modulus: int) -> int:
    result = 1
    base %= modulus
    while exponent > 0:
        if exponent & 1:
            result = (result * base) % modulus
        base = (base * base) % modulus
        exponent >>= 1
    return result


p = 467
g = 2
A = 132
B = 363
a = 0x7F

calculated_A = modexp(g, a, p)
if calculated_A != A:
    raise ValueError("The private fragment does not match public value A")

shared_secret = modexp(B, a, p)
seed = f"VAULT217-JANUS-{shared_secret}"
recovery_key = hashlib.sha256(seed.encode("utf-8")).hexdigest()

print("A calculado:", calculated_A)
print("Secreto compartido:", shared_secret)
print("Recovery key:", recovery_key)
