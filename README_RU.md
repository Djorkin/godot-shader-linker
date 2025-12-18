# Godot Shader Linker (GSL)

**Godot Shader Linker** - инструмент для автоматического импорта нод‑графов материалов из Blender в Godot.
Он конвертирует материалы **EEVEE** в Godot‑шейдеры одним кликом, сохраняя процедурную логику **без запекания текстур**.

## Что делает плагин и зачем он нужен

Обычные экспорты из Blender в игровые движки хорошо переносят геометрию и базовые PBR‑параметры, но почти всегда не переносят процедурность: нод‑граф материалов, процедурные текстуры и кастомную шейдерную логику. GSL это попытка сократить этот разрыв — он считывает нод‑граф EEVEE и генерирует аналогичный шейдер в Godot, сохраняя процедурную логику без запекания текстур.

Плагин состоит из двух компонентов: Python‑аддон для Blender запускает локальный сервер
и сериализует граф нод из Shader Editor, а GDScript‑плагин в Godot принимает эти данные и генерирует аналогичный шейдер.
Кнопки **Link Shader** и **Link Material** создают готовые `.gdshader` и `.tres` файлы.

Процедурные текстуры вычисляются на GPU Godot в реальном времени, а не запекаются -
это позволяет анимировать параметры через GDScript или `AnimationPlayer`.

## Основные возможности

* One-click import. Кнопки **Link Shader / Material** создают `.gdshader` и `.tres`.
* Процедурные текстуры — на стороне GPU Godot
* Полная интеграция с экосистемой Godot (Inspector, WorldEnvironment, пост-процессы)
* Анимации параметров через GDScript или `AnimationPlayer`

## Установка

1. Скопируйте директорию `addons/godot_shader_linker_(gsl)` в проект Godot.  
2. В **Project → Plugins** активируйте «Godot Shader Linker (GSL)».  
3. В нижней панели редактора (**Bottom Panel**) появится вкладка **Shader Linker**.

### Установка Blender-аддона

#### Способ 1 — через zip (рекомендуется)
1. В Blender откройте **Edit → Preferences → Add-ons → Install…**  
2. Выберите архив `gls_blender_exp.zip`.  
3. В списке аддонов включите **GSL Exporter**.  
4. Перейдите в **Godot** - в панели **Shader Linker** статус станет `Status: Connected to Blender`.

#### Способ 2 — через Scripts Directories (удобно для разработки)
1. В Blender откройте **Edit → Preferences → File Paths → Scripts Directories → Add**.  
2. Укажите путь на папку `.../addons/godot_shader_linker_(gsl)/Blender`, `Name: gls_blender_exp`.  
3. Перезапустите Blender и активируйте **GSL Exporter** (`Add-ons`).  
4. Перейдите в **Godot** - в панели **Shader Linker** статус станет `Status: Connected to Blender`.

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
  - Color Ramp (Linear, Constant)

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
* Если используете `Generated` координаты, перед просмотром результата выполните **Bake AABB** (запечка `bbox_min/bbox_max` в Instance Shader Parameters).
* В отдельных сочетаниях узлов итоговый сигнал может оставаться нефильтрованным, что приводит к заметному алиасингу.

## Рекомендации по визуальному соответствию с Blender
* Совместите перспективу камеры в Godot и Blender.  
* Добавьте `WorldEnvironment`, загрузите ту же HDRI (`Sky`) и поверните на 90°.  
* Во вкладке **Tonemap** выберите **Linear** или **AgX**.  

## Лицензия
Проект распространяется на условиях **GPL-3.0-or-later**.

## Атрибуции
Части реализации адаптированы из исходников Blender для достижения совпадения поведения 1 в 1 (Blender исходники распространяется по GPL-2.0-or-later):

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
