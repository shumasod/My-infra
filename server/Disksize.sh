//サーバのディスクサイズ取得
const Submarine = require('submarine');

const GetVolSize = class extends Submarine {
 query() {
   return {
     volkb_sizes: String.raw`
       df -P \
       | grep -v "^Filesystem" \
       | awk '{print $3+$4}'
     `,
   };
 }

 format(stats) {
   return {
     volkb_largest: stats.volkb_sizes
       .split(/\r\n|\r|\n/)
       .sort((a, b) => b * 1 - a * 1)[0], // largest volume is chosen.
   };
 }

 test(r) {
   const { stats } = r;
   return {
     size_enough: 2 * 1024 * 1024 < stats.volkb_largest,
   };
 }
};