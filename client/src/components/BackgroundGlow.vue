<template>
  <div class="background-glow">
    <div class="glow glow-1"></div>
    <div class="glow glow-2"></div>
    <div class="glow glow-3"></div>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.background-glow {
  position: fixed;
  inset: 0;
  overflow: hidden;
  z-index: 0;
  pointer-events: none;
}

.glow {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.4;
}

.glow-1 {
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, #4f7cff 0%, transparent 70%);
  top: -100px;
  right: -50px;
  animation: float1 10s ease-in-out infinite;
}

.glow-2 {
  width: 350px;
  height: 350px;
  background: radial-gradient(circle, #a855f7 0%, transparent 70%);
  bottom: -80px;
  left: -30px;
  animation: float2 12s ease-in-out infinite;
}

.glow-3 {
  width: 280px;
  height: 280px;
  background: radial-gradient(circle, #06b6d4 0%, transparent 70%);
  top: 40%;
  left: 60%;
  animation: float3 9s ease-in-out infinite;
}

@keyframes float1 {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(-60px, 80px) scale(1.15); }
}

@keyframes float2 {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(70px, -60px) scale(1.1); }
}

@keyframes float3 {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(-50px, 50px) scale(0.9); }
}
</style>
