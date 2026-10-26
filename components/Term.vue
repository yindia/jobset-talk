<script setup lang="ts">
// A terminal window: the command sits in the title bar, the output in the body.
// Put a ```text code block in the default slot for the output.
defineProps<{
  cmd: string
}>()
</script>

<template>
  <figure class="term">
    <figcaption class="term-bar">
      <span class="term-dots" aria-hidden="true"><i /><i /><i /></span>
      <code class="term-cmd"><span class="term-prompt">$</span> {{ cmd }}</code>
    </figcaption>
    <div class="term-body">
      <slot />
    </div>
  </figure>
</template>
