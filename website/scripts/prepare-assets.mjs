// Run from website/. Source screenshots use demo data from the existing app tests.
import sharp from 'sharp';
import { mkdir, writeFile } from 'node:fs/promises';
const sources = {
  'today-de': 'today-de',
  'today-en': 'today-en',
  'plan-de': 'plan-de',
  'plan-en': 'plan-en',
  'workout-de': 'workout-de',
  'workout-en': 'workout-en',
  'history-de': 'review-plan-actual-de',
  'history-en': 'review-plan-actual-en',
};
await mkdir('public/images', { recursive: true });
for (const [target, source] of Object.entries(sources)) {
  await sharp(`../docs/screenshots/${source}.png`)
    .resize({ width: 640 })
    .webp({ quality: 84 })
    .toFile(`public/images/${target}.webp`);
}
for (const lang of ['de', 'en']) {
  const lines =
    lang === 'de'
      ? ['Dein Rudertraining.', 'Dein Rhythmus.']
      : ['Your rowing.', 'Your rhythm.'];
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#f6f6ef"/><rect x="850" width="350" height="630" fill="#d6efa6"/>
  <g fill="#133433" transform="translate(63 66) rotate(40 32 32)"><rect x="19" y="12" width="10" height="35" rx="5"/><rect x="35" y="17" width="10" height="35" rx="5"/></g>
  <g font-family="Helvetica,Arial,sans-serif" fill="#133433"><text x="139" y="111" font-size="44" font-weight="700">rowivo.</text><text x="70" y="288" font-size="65" font-weight="700">${lines[0]}</text><text x="70" y="371" font-size="65" font-weight="700" fill="#296659">${lines[1]}</text><text x="73" y="535" font-size="23">rowivo.kromerlorenz.at</text></g>
  <g stroke="#296659" fill="none" opacity=".25">${Array.from({ length: 9 }, (_, i) => `<path d="M820 ${200 + i * 29} C960 ${60 + i * 29} 1070 ${430 + i * 29} 1250 ${220 + i * 29}"/>`).join('')}</g></svg>`;
  await sharp(Buffer.from(svg))
    .png()
    .toFile(`public/images/social-${lang}.png`);
}
await writeFile(
  'public/images/sources.txt',
  Object.entries(sources)
    .map(
      ([target, source]) => `${target}.webp ← docs/screenshots/${source}.png`,
    )
    .join('\n') +
    '\nSocial cards: original Rowivo typography and vector artwork.\n',
);
