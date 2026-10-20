# 背景素材の生成記録

内蔵の image_gen を使用し、Aの見本を絵柄の参照にして、操作する物体を含まない背景を5環境ぶん生成した。全画像1672×941px。ゲーム内では背景だけを画面全体へ表示し、地形・仕掛け・キャラクターは別に描画する。

生成後、波や煙の揺れ、溶岩の泡と火の粉、瘴気、雲・星をGodotの描画とシェーダーで緩やかにループさせる。緑の生物と傘の既存素材は編集していない。

参照画像：`docs/art-direction/environment-examples.png`（環境と描き方）、`docs/art-direction/gimmicks-a.png`（Aの描き方）。

## base

保存先：base.png。生成元：`exec-2702910f-8a17-4288-9d21-0a2774a81d80.png`。

```text
Use case: stylized-concept.
Asset type: production background texture for the 2D hand-drawn Japanese platformer Ninja Buttobi-kun Galaxy. Reference image 1 is the approved environment illustration style, reference 2 the approved A flat drawing style. They are STYLE references only; do NOT copy foreground objects.
Create ONE standalone wide landscape BACKGROUND ONLY, target 1536 x 864, filling the whole image edge to edge. Strict side-view game backdrop. Absolutely NO foreground floors, platforms, walls, ceiling ledges, characters, gadgets, springs, arrows, pickups, goals, flags, borders, text, labels or UI. The engine will draw them separately.
Match the modest original handmade art: gently uneven lines, broad mostly flat color regions, a few big details, at most one secondary tone per material. No paper texture, gradients, realistic texture, 3D, glow, fine clutter or photorealism. Distant outlines softer and lower contrast than interactive foreground objects will be. Keep the middle of the image calm and spacious for gameplay; concentrate worldbuilding in distance and lower third. Clear scenic silhouettes, no near-facing pillars that resemble playable terrain. No houses/bridges directly aligned with foreground traversal.

Environment: orderly friendly SPACE BASE. Muted navy-purple sky, a pale lavender cratered moon upper right, a few small sparse stars. Bottom half: distant cream/blue-gray rounded base buildings, simple antenna masts, one satellite dish, very few warm illuminated window strips. A clear sense of a maintained base in outer space, slightly odd and approachable. No Japanese architecture. Buildings are subdued distant silhouettes and never look like foreground collision geometry.
```

## inhabited

保存先：inhabited.png。生成元：`exec-d9a997d4-4fd2-4447-a081-7c554a16f6ca.png`。

```text
Use case: stylized-concept.
Asset type: production background texture for the 2D hand-drawn Japanese platformer Ninja Buttobi-kun Galaxy. Reference image 1 is the approved environment illustration style, reference 2 the approved A flat drawing style. They are STYLE references only; do NOT copy foreground objects.
Create ONE standalone wide landscape BACKGROUND ONLY, target 1536 x 864, filling the whole image edge to edge. Strict side-view game backdrop. Absolutely NO foreground floors, platforms, walls, ceiling ledges, characters, gadgets, springs, arrows, pickups, goals, flags, borders, text, labels or UI. The engine will draw them separately.
Match the modest original handmade art: gently uneven lines, broad mostly flat color regions, a few big details, at most one secondary tone per material. No paper texture, gradients, realistic texture, 3D, glow, fine clutter or photorealism. Distant outlines softer and lower contrast than interactive foreground objects will be. Keep the middle of the image calm and spacious for gameplay; concentrate worldbuilding in distance and lower third. Clear scenic silhouettes, no near-facing pillars that resemble playable terrain. No houses/bridges directly aligned with foreground traversal.

Environment: an INHABITED ALIEN PLANET. Quiet dusty blue sky, a small pale moon, two broad simple clouds. Lower half: rolling muted green hills, a few rounded cream space houses with blue domed roofs, little cultivated garden patches, a few simple trees. Welcoming everyday settlement with space-era architecture, no Japanese temples or castles. Buildings and garden details low contrast, no NPCs. Reserve a wide calm open sky in the center.
```

## wild

保存先：wild.png。生成元：`exec-7546f184-313b-426f-ba3e-8b4441b88f2c.png`。

```text
Use case: stylized-concept.
Asset type: production background texture for the 2D hand-drawn Japanese platformer Ninja Buttobi-kun Galaxy. Reference image 1 is the approved environment illustration style, reference 2 the approved A flat drawing style. They are STYLE references only; do NOT copy foreground objects.
Create ONE standalone wide landscape BACKGROUND ONLY, target 1536 x 864, filling the whole image edge to edge. Strict side-view game backdrop. Absolutely NO foreground floors, platforms, walls, ceiling ledges, characters, gadgets, springs, arrows, pickups, goals, flags, borders, text, labels or UI. The engine will draw them separately.
Match the modest original handmade art: gently uneven lines, broad mostly flat color regions, a few big details, at most one secondary tone per material. No paper texture, gradients, realistic texture, 3D, glow, fine clutter or photorealism. Distant outlines softer and lower contrast than interactive foreground objects will be. Keep the middle of the image calm and spacious for gameplay; concentrate worldbuilding in distance and lower third. Clear scenic silhouettes, no near-facing pillars that resemble playable terrain. No houses/bridges directly aligned with foreground traversal.

Environment: an UNDEVELOPED ALIEN PLANET. Dusty lavender sky, a large pale moon at upper right. Distant ochre and muted purple rock formations with a few broad arched shapes and odd tall mushroom-like plants. No settlement, road, houses or machinery. A few simple pink alien plants near the bottom edge, not foreground plants. Natural and unfamiliar but still approachable. Terrain formations belong clearly to the distance, not an opaque playable ledge across the screen.
```

## lava

保存先：lava.png。生成元：`exec-2a9a6354-405c-44fd-af75-43a5b55d91bd.png`。

```text
Use case: stylized-concept.
Asset type: production background texture for the 2D hand-drawn Japanese platformer Ninja Buttobi-kun Galaxy. Reference image 1 is the approved environment illustration style, reference 2 the approved A flat drawing style. They are STYLE references only; do NOT copy foreground objects.
Create ONE standalone wide landscape BACKGROUND ONLY, target 1536 x 864, filling the whole image edge to edge. Strict side-view game backdrop. Absolutely NO foreground floors, platforms, walls, ceiling ledges, characters, gadgets, springs, arrows, pickups, goals, flags, borders, text, labels or UI. The engine will draw them separately.
Match the modest original handmade art: gently uneven lines, broad mostly flat color regions, a few big details, at most one secondary tone per material. No paper texture, gradients, realistic texture, 3D, glow, fine clutter or photorealism. Distant outlines softer and lower contrast than interactive foreground objects will be. Keep the middle of the image calm and spacious for gameplay; concentrate worldbuilding in distance and lower third. Clear scenic silhouettes, no near-facing pillars that resemble playable terrain. No houses/bridges directly aligned with foreground traversal.

Environment: an extremely INHOSPITABLE LAVA PLANET matching the approved harsh direction. Charcoal volcano silhouettes, broad eruption mouths, orange-red molten rivers, thick dark red-brown smoke clouds across the upper sky and a huge dark fiery cracked planet. A wide molten sea occupies the bottom third, with simple red-orange base and a few broad yellow-orange flow bands. The lower sea should be mostly flat uninterrupted color so the engine can animate bubbles and waves over it. NO baked large boiling bubbles or spark particles: these will be animated separately. Make the world fiercely hot and unlivable, big clear black/orange masses. At the center, use subdued dark red distant mountains behind the future gadgets; brightest lava concentrated below y=0.7 and far volcano mouths. No fine sparks, cinematic bloom or texture.
```

## evil

保存先：evil.png。生成元：`exec-19ee2abf-a8c3-4458-b136-b4376c30b1f2.png`。

```text
Use case: stylized-concept.
Asset type: production background texture for the 2D hand-drawn Japanese platformer Ninja Buttobi-kun Galaxy. Reference image 1 is the approved environment illustration style, reference 2 the approved A flat drawing style. They are STYLE references only; do NOT copy foreground objects.
Create ONE standalone wide landscape BACKGROUND ONLY, target 1536 x 864, filling the whole image edge to edge. Strict side-view game backdrop. Absolutely NO foreground floors, platforms, walls, ceiling ledges, characters, gadgets, springs, arrows, pickups, goals, flags, borders, text, labels or UI. The engine will draw them separately.
Match the modest original handmade art: gently uneven lines, broad mostly flat color regions, a few big details, at most one secondary tone per material. No paper texture, gradients, realistic texture, 3D, glow, fine clutter or photorealism. Distant outlines softer and lower contrast than interactive foreground objects will be. Keep the middle of the image calm and spacious for gameplay; concentrate worldbuilding in distance and lower third. Clear scenic silhouettes, no near-facing pillars that resemble playable terrain. No houses/bridges directly aligned with foreground traversal.

Environment: an extremely INHOSPITABLE PLANET FULL OF EVIL AURA matching the approved harsh direction. Deep near-black plum sky, giant black celestial disk in the upper right circled by a lopsided broad purple vortex, distant crooked hooked rock spires, flat curled bands of purple miasma around the distant valley. A cursed oppressive landscape, not a gentle purple sunset. Few broad shapes and flat layered silhouettes. Keep the central background behind future gameplay gadgets dark and quiet, bright purple mostly in sky vortex and valley bottom. No monster faces, eyes, skulls, blood, enemies, magic collectibles or laser beams. The engine adds slow drifting mist independently. No volumetric fog, neon bloom or paper texture.
```

## daylight-anime

保存先：`daylight-anime.png`。内蔵のimage_genで生成。生成元：`exec-7cf2360c-f7f6-4ca9-9f77-6e2fff86ffa5.png`。画像サイズ：1672×941px。青空版の比較用シーンに使用し、雲と光の動きは`daylight.gdshader`で加える。

```text
Use case: stylized-concept. Asset type: production-ready painted sky background texture for a 2D game. Generate a wide 16:9 landscape sky-only illustration, preferably 2048x1152. Primary request: an original luminous blue daytime sky with the emotional atmosphere and finely painted cinematic Japanese anime background treatment associated with the sky scenes of the film Your Name (君の名は。). No characters or film-specific scene recreation. Deep clean azure at the top, rich cyan in the middle, delicate pale turquoise atmospheric haze near the bottom. Large voluminous cumulus cloud banks with intricate wispy edges, softly modeled cool lavender and periwinkle shadows and dazzling warm-white sunlit rims; detailed hand-painted cloud volume, translucent atmospheric depth. Composition: the sky fills the entire frame with no ground or horizon; airy blue negative space through the middle, substantial beautiful cloud silhouettes visible near BOTH outer vertical edges because the game uses the outermost left and right 10 percent as side panels; white clouds should still break against readable blue at each side. A soft brilliant sunlight glow enters near the upper left, with restrained fine shafts of light extending diagonally downward through the atmosphere. Elegant restrained bloom, gentle pale peach highlights, fresh clear summer daylight. Soft painterly edges, no thick outlines, no geometric cloud icons, no flat cartoon circles, no cute sun symbol. No buildings, terrain, people, birds, planets, stars, meteors, rainbows, logos, lettering, borders, or watermark. Opaque image, not transparent.
```
