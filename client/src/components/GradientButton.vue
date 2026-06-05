<template>
  <button
    class="gradient-btn"
    :class="{ disabled, loading }"
    :disabled="disabled || loading"
    @click="$emit('click')"
  >
    <span v-if="loading" class="spinner"></span>
    <slot />
  </button>
</template>

<script setup lang="ts">
defineProps<{
  disabled?: boolean
  loading?: boolean
}>()

defineEmits<{
  click: []
}>()
</script>

<style scoped>
.gradient-btn {
  width: 100%;
  padding: 14px 0;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #4f7cff, #a855f7);
  color: #fff;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  position: relative;
  transition: box-shadow 0.3s, transform 0.15s;
}

.gradient-btn:hover:not(.disabled):not(.loading) {
  box-shadow: 0 0 24px rgba(79, 124, 255, 0.4), 0 0 48px rgba(168, 85, 247, 0.2);
  transform: translateY(-1px);
}

.gradient-btn:active:not(.disabled):not(.loading) {
  transform: translateY(0);
}

.gradient-btn.disabled,
.gradient-btn.loading {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner {
  display: inline-block;
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-right: 8px;
  vertical-align: middle;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
