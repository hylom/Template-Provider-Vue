<template>
  <subcomponent v-for="s in items"
                :item="obj"
                text="the_text" :prop="s"></subcomponent>
</template>
