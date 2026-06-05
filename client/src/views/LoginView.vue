<template>
  <div class="login-view">
    <BackgroundGlow />
    <LoginCard />
  </div>
</template>

<script setup lang="ts">
import BackgroundGlow from '@/components/BackgroundGlow.vue'
import LoginCard from '@/components/LoginCard.vue'
</script>

<style scoped>
.login-view {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}
</style>
