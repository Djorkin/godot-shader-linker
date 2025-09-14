# Godot Shader Linker (GSL)

**GSL** — сборщик шейдерных графов для Godot 4.2+, который принимает описание нодовых сетей из внешних DCC и собирает эквивалентный шейдер под Godot. Ядро GSL портирует ноды (их семантику и формулы), а текущая техническая реализация ориентирована на граф материалов Blender (рендер EEVEE).

## Основные возможности

* One-click import. Кнопки **Link Shader / Material** создают `.gdshader` и `.tres`.
* Парсинг нодовой сети и генерация Godot-шейдера «на лету»
* Процедурные текстуры — на стороне GPU Godot
* Полная интеграция с экосистемой Godot (Inspector, WorldEnvironment, пост-процессы)
* Анимации параметров через GDScript или `AnimationPlayer`

## Установка
1. Скопируйте директорию `addons/godot_shader_linker_(gsl)` в проект Godot.  
2. В **Project → Plugins** активируйте «Godot Shader Linker (GSL)».  
3. В 3D-вью появится UI GSL (`Ctrl + G` — скрыть/показать).

### Настройка Blender-аддона
1. **Edit → Preferences → File Paths → Scripts Directories → Add** — укажите путь `.../addons/godot_shader_linker_(gsl)/Blender`, `Name: gls_blender_exp`.  
2. Перезапустите Blender и активируйте **GSL Exporter** (`Add-ons`).  
3. В настройках аддона задайте путь к проекту **Godot** (нужно для импорта текстур).  
4. Перейдите в Godot — в **Output** появится `Blender server started`.

## Быстрый старт
1. В Blender выберите материал в **Shader Editor**.  
2. Нажмите **Link Shader** или **Link Material**.  
3. В Godot появятся сгенерированные `.gdshader` / `.tres`.  
4. Примените материал к MeshInstance и проверьте результат.

## Поддерживаемые ноды
- Координаты
  - Texture Coordinate
  - Mapping

- Текстуры
  - Image Texture (проекции: Flat, Box, Sphere, Tube; интерполяции: Linear, Closest; extension: Repeat, Extend)
  - Noise Texture
  - Fractal Noise

- Цвет
  - Color Ramp

- Преобразования
  - Combine Color
  - Separate Color
  - Combine XYZ
  - Separate XYZ

- Математика
  - Math (подмножество режимов: Add, Subtract, Multiply, Divide, Power, Modulo, Floor, Ceil, Truncate, PingPong, Atan2, Compare и др.)
  - Vector Math (подмножество: Add, Subtract, Multiply, Divide, Dot Product, Cross Product, Normalize, Length, Distance, Scale, Project, Reflect, Refract, Wrap, Snap)

- Нормали и микрорельеф
  - Normal Map (Tangent Space)
  - Bump

- Шейдинг
  - Principled BSDF (базовый набор, упрощённый coat)

- Выход
  - Material Output

## Известные проблемы
* **TAA** может мерцать на анимируемых/процедурных материалах. Используйте **FXAA** или уменьшайте динамику параметров.  
* **SDFGI** работает некорректно с прозрачными материалами.
* Для материалов с `Transmission > 0` выставьте `transparency > 0`, иначе объект будет чёрным.
* Закрывайте шейдер в Shader Editor при перезаписи материала/шейдера, иначе будет версия, созданная ранее.
* В версии v0.2 после первого импорта материала иногда возникает визуальное растяжение. Нажмите кнопку CPU DATA, чтобы обновить данные и исправить отображение.
* В отдельных сочетаниях узлов итоговый сигнал может оставаться нефильтрованным, что приводит к заметному алиасингу.

## Рекомендации по визуальному соответствию с Blender
* Совместите перспективу камеры в Godot и Blender.  
* Добавьте `WorldEnvironment`, загрузите ту же HDRI (`Sky`) и поверните на 90°.  
* Во вкладке **Tonemap** выберите **AgX**.  

## Лицензия
Проект распространяется на условиях **GPL-3.0-or-later**.

## Атрибуции
Части реализации адаптированы из исходников Blender для достижения совпадения поведения (Blender распространяется по GPL-2.0-or-later):

- GPU Vector Math и утилиты:
  - source/blender/gpu/shaders/common/gpu_shader_math_vector_lib.glsl
  - source/blender/gpu/shaders/common/gpu_shader_math_base_lib.glsl
  - source/blender/gpu/shaders/material/gpu_shader_material_vector_math.glsl
- Color Ramp:
  - source/blender/gpu/shaders/common/gpu_shader_common_color_ramp.glsl
- Principled BSDF и сопутствующие функции:
  - source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
- Bump:
  - source/blender/gpu/shaders/material/gpu_shader_material_bump.glsl
- Image Texture / проекции и сэмплинг:
  - source/blender/gpu/shaders/material/gpu_shader_material_tex_image.glsl
- Noise / Fractal Noise:
  - source/blender/gpu/shaders/material/gpu_shader_material_noise.glsl
- Хэши/шума:
  - source/blender/gpu/shaders/common/gpu_shader_common_hash.glsl
- Цветовые преобразования (Cycles):
  - intern/cycles/kernel/svm/node_color.h (порт отдельных утилит)

Ссылки на конкретные участки и формулы также продублированы в шапках соответствующих `.gdshaderinc` файлов (комментарий «Portions adapted from Blender…»).

## Ссылки

* Документация: `docs/` *(WIP)*
* Blender-аддон: `/Blender/` *(WIP)*
