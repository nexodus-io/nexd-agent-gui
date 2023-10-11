// import { defineConfig } from 'vite';
//
// // https://vitejs.dev/config
// export default defineConfig({
//   resolve: {
//     // Some libs that can run in both Web and Node.js, such as `axios`, we need to tell Vite to build them in Node.js.
//     browserField: false,
//     mainFields: ['module', 'jsnext:main', 'jsnext'],
//   },
// });
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  build: {
    rollupOptions: {
      // Override the output directory
      output: {
        dir: path.resolve(__dirname, 'dist')
      }
    }
  },
  resolve: {
    browserField: false,
    mainFields: ['module', 'jsnext:main', 'jsnext'],
    alias: {
      // If you have custom aliases, add them here
    }
  },
  esbuild: {
    // Specify that we're building for a NodeJS environment
    platform: 'node',
    // Enable TypeScript support
    loader: 'ts'
  }
});
