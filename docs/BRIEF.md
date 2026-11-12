# NXOR iOS — бриф для разработки

Нативное iOS-приложение (SwiftUI) по мобильному веб-интерфейсу nxor.ai.
Этот файл — результат анализа сайта, его API и клиентского кода. Положи его в корень проекта и работай по нему.

## Правила для агента

- Генерации (`/images/generate`, `/videos/generate`, `/videos/:id/finalize`), сообщения в чат, удаление, перенос, оплаты **тратят кредиты или меняют аккаунт**. Не вызывай их без явного «да» пользователя. Цены (`/quote`) и все GET — можно.
- Сначала всё на мок-данных (этапы 1–3), реальный API — этап 4.
- Собирай и проверяй через `xcodebuild` и симулятор после каждого экрана, присылай скриншоты.

## Решения по умолчанию (пока пользователь не скажет иначе)

1. Оплаты в приложении нет: только баланс/тариф, без кнопок покупки (правило App Store 3.1.1).
2. Вход только по email-коду (Google требует серверной поддержки и Sign in with Apple).
3. Языки: английский + русский. Арабский/RTL — позже.
4. Цель — личное использование (Xcode / TestFlight), не публикация.

## Стек

- Xcode 26, SwiftUI, iOS 17+, Swift Concurrency, `@Observable`.
- Без сторонних зависимостей (AVKit для видео, PhotosUI для выбора медиа).
- Структура: `DesignSystem/`, `Networking/` (APIClient, SSE, модели), `Features/{Auth,Chat,Sidebar,Studio,Library,Presets,Billing,Settings}`, `Mocks/` (JSON-фикстуры реальной формы).
- Флаг `useMocks` для переключения мок/реальный API.

## Дизайн-токены (из CSS сайта)

| Токен | Значение |
|---|---|
| `--nx-bg` | `#08090a` |
| `--nx-surface` | `#0b0d10` |
| `--nx-raised` | `#12151a` |
| `--nx-line` | `#23272d` |
| `--nx-line-2` | `#2e3238` |
| `--nx-ink` | `#fff` |
| `--nx-ink-soft` | `#eef1f5` |
| `--nx-ink-2` | `#aeb7c2` |
| `--nx-ink-3` | `#8a93a0` |
| `--nx-muted` | `#6e7681` |
| `--nx-accent` | `#12e0ff` |
| `--nx-on-accent` / `--nx-btn-ink` | `#08090a` / `#0b0d10` |
| `--nx-warn-ink` | `#ffd166` |
| `--nx-danger` | `#ff6b6b` |
| `--nx-grad-brand` | `135deg: #ff3dd1 0%, #7b5bff 55%, #12e0ff 100%` |
| `--nx-grad-hero-ink` (текст заголовков) | `104deg: #2e5bff 0%, #12e0ff 38%, #c86bc8 70%, #ff3dd1 100%` |
| `--nx-grad-frame` (рамки активных карточек) | `90deg: #12e0ff 0%, #2e5bff 52%, #ff3dd1 100%` |
| `--nx-grad-btn-active` (главная светлая кнопка) | `175deg: #e6ecf4 0%, #c9d2de 55%, #dce3ec 100%` |
| `--nx-grad-sidebar` | `139deg: #12151a 0%, #0a0b0d 50%, #0f1216 100%` |
| `--nx-grad-skeleton` | `90deg: #14171b 0%, #22262c 42%, #14171b 84%` |
| `--nx-grad-toggle` | `90deg: #2e5bff 0%, #12e0ff 100%` |
| `--nx-grad-credits` | `90deg: #2e5bff 0%, #12e0ff 40%, #ff3dd1 100%` |
| `--nx-grad-stripes` (аватар-заглушка) | `repeating 135deg: #1a1e23 0 5px, #14171b 5px 10px` |
| Анимации | press 90ms, hover 0.2s, pop 0.3s, enter 0.62s |

Шрифты (встроить в бандл, все под OFL/свободными лицензиями):
- **Archivo 900 Italic** — заголовки капслоком («ASK, THEN RENDER.», «LIBRARY», «RUN SETTINGS»), letter-spacing ≈ −0.03em.
- **Google Sans Text** 400/500/700 — основной текст (если недоступен — Inter или SF Pro).
- **IBM Plex Mono** 500 — подписи-метки капслоком, 9–12pt, letter-spacing ≈ 0.2em, цвет `--nx-muted` (`START WITH`, `FLUX 2 PRO · 35 CREDITS`, `IMAGE CREATED`).

Фирменные элементы:
- Кнопки и квадратные иконки-кнопки со **скошенными углами** (срез ~12pt: правый верх и левый низ). Главная кнопка — светлый градиент `btn-active`, тёмный текст Archivo Italic. Кнопка отправки — серый скошенный квадрат со стрелкой ↑.
- Тонкие рамки 1px `--nx-line`, почти без скруглений (0–2pt). Чип «FAST» — капсула.
- Логотип: белый «X» + «NXOR» Archivo Black Italic.
- Выбранный сегмент: фон `--nx-raised`, рамка акцентом или светлым.
- Нижние листы (sheet) с ручкой-граббером, фон `--nx-surface`.

## Экраны (по скриншотам)

1. **Вход.** «WELCOME BACK.», поле email, «CONTINUE WITH EMAIL», «Continue with Google» (пока скрыть). Шаг 2: «CHECK YOUR INBOX.», 6 полей кода (OtpInput, `oneTimeCode`), «Verify & continue», повторная отправка через 60 с, «Change email».
2. **Главная = чат.** Верх: кнопка меню (скошенный квадрат) + логотип по центру. Пустое состояние: большой X, «ASK, THEN RENDER.» (белый) / «EVERY ENGINE, ONE CHAT.» (градиент hero-ink), «START WITH» + «See all capabilities ›», горизонтальная лента карточек (Use a preset / Make a video / Make an image / Search the web). Композер внизу: плейсхолдер «Try: …», кнопка «+» (вложения), чип режима «⚡ FAST ⌃», кнопка ↑.
3. **Выбор режима** (поповер над чипом): Fast — «QUICK ANSWERS · UP TO CLAUDE HAIKU 5.5», Smart — «BALANCED · UP TO CLAUDE SONNET 5.5», Genius — «COMPLEX WORK · UP TO CLAUDE SONNET 5.5». Данные из `/chat/tiers` (есть `locked`/`requires`).
4. **«WHAT CAN I DO?»** — лист с группами CREATE / EDIT / PRESETS / RESEARCH / FILES, строки с иконкой, описанием и «TRY IT» (подставляет пример в композер). Данные: `/chat/capabilities`.
5. **Чат-ветка.** Сообщения пользователя (+ вложения), ответы ассистента (markdown), строка статуса во время стрима (thinking / writing_prompt / generating_video …), карточка предложения (промпт моноширинным, модель, цена, «Run»/«Dismiss»), карточка результата (картинка/видео-плеер), подпись «PIXVERSE V6 · 180 CREDITS · VIDEO CREATED», строка «CLAUDE SONNET 5.5» + копировать + перегенерировать.
6. **Боковое меню** (выезжает слева, градиент sidebar): логотип, ×, «SEARCH», вкладки CHAT | STUDIO (акцентная линия), «CHATS 150 +», список чатов, внизу профиль (полосатый аватар, имя, «POWER USER · 4,800 CREDITS», ⌃), кнопки «PRESETS 123», «LIBRARY 91», ⓘ (help). STUDIO → экран Studio.
7. **Studio (изображение/видео).** «LIBRARY · N ASSETS», UPLOAD, SELECT, сегмент ALL/IMAGE/VIDEO(/AUDIO/DRAFTS), сетка 2 колонки по месяцам («NOVEMBER 2026»), на плитке ↓ и …, метка «REFERENCE», длительность «0:06». Композер: «Describe the picture», «⚡ AI PROMPT», переключатель 🖼/🎥 (рамка акцентом), чип модели «FLUX.1 KONTEXT · 21:9 ⌃», цена «25 CR», ↑.
8. **Run settings** (лист): MODEL (имя + провайдер, ⌄ → список семейств), PREPARE IMAGES / IMAGE SHEET (тумблеры, для видео), REFERENCES (0/1, «+ Add media»), OUTPUT (соотношение, качество/разрешение, формат), DURATION (слайдер 4–10 сек), ADVANCED. Всё строится по `variants[].body` и `dimensions` выбранного семейства.
9. **Library.** GENERATIONS | UPLOADS, выбор проекта («GRAIN ⌄»), ALL TYPES / IMAGES / VIDEOS / DRAFTS, SELECT → нижняя панель «0 SELECTED · SELECT ALL · DOWNLOAD ZIP · MOVE TO… · DELETE».
10. **Просмотр ассета.** «‹ IMAGE», медиа на всю ширину, стрелки ‹ ›, … и 🗑 (красная рамка), PROMPT + COPY + SEE ALL, сетка MODEL / QUALITY / SIZE / RENDER TIME.
11. **Presets.** «PRESETS 123», чипы ALL / PORTRAIT / PRODUCT / CAMERA / VIDEO / SEASONAL, карточки с превью (видео автоплей), имя, «VIDEO · FROM 450 CR», «USE PRESET».
12. **Карточка пресета.** Заголовок, «SAMPLE OUTPUT», «PROMPT · OPTIONAL», «YOUR PHOTO REQUIRED» (зона загрузки), «LOCKED BY PRESET · ASPECT 16:9», кнопка «USE PRESET · 25 CR».
13. **Billing** (только просмотр): CURRENT BALANCE / RESERVED / MONTHLY GRANT, тарифы Starter / Professional / Power User (текущий отмечен), пакеты кредитов — без покупки.
14. **Settings.** Имя, email, Manage plan (ссылка на сайт), Connected apps (инструкция MCP), Memory, выход. **Help** — FAQ.

## API

База: `https://api.nxor.ai/v1`. Все запросы с cookie (в URLSession — `HTTPCookieStorage.shared`, `httpShouldSetCookies = true`).

### Авторизация
- `POST /auth/magic-link` `{email}` → письмо со ссылкой и 6-значным кодом (15 мин). 429 → `retryAfterMs`.
- `POST /auth/magic-link/code` `{email, code}` → `{authEvent: "login"|"signup", authMethod}` + Set-Cookie.
- Cookie: `access_token` (api.nxor.ai, httpOnly, 15 мин), `refresh_token` (path `/v1/auth`, httpOnly, 30 дней).
- При 401: один раз `POST /auth/refresh` (204 = ок), затем повтор запроса; если refresh не удался → экран входа.
- `POST /auth/logout`.

### Пользователь и баланс
- `GET /users/me` → `{user{id,email,name,locale,lastProjectId,…}, subscription{status,interval,currentPeriodEnd,cancelAtPeriodEnd,plan{slug,name,priceMonthlyUsd,monthlyTokenGrant,…}}, usage{credits{available,reserved,monthlyGrant}, creditMetered, …}}`
- `GET /credits/balance` → `{available, reserved}`; `GET /credits/history?page&pageSize`
- `GET /subscriptions/plans`, `GET /billing/topups`

### Каталог
- `GET /image-models`, `GET /video-models` → `[ {family,label,provider,description, dimensions:[{key,label,values,options:[{value,label}]}], variants:[{slug, dims{operation,resolution,tier,duration,audio…}, body{prompt:"required|optional|none", aspectRatio:[…], source, maxSourceImages, maxSceneImages, negativePrompt, seed, endImage, firstFrame, mask, audioReference, videoInput, sourceGeneration, maxVideoFiles, maxAudioFiles, …}}] } ]`
  Выбор варианта = набор значений `dimensions` → ищем `variant` с такими `dims` → его `body` определяет поля формы.
- `GET /chat/tiers` → `[{tier:"fast|smart|genius", locked, requires, files, chat{slug,name,provider}, images[], videos[]}]`
- `GET /chat/capabilities` → `[{id, group, icon, title, promptLine, tiers, available, reason, …}]`
- `GET /presets`, `GET /presets/:slug` → `{slug, kind, name, description, tags, previewImageUrl, previewVideoUrl, inputs:[{key,label,requirement,hint,maxFiles,accepts,upload,maxBytes,formats}], dimensions, options:[{dims,costBand,credits,aspectRatio,…}], userPrompt, userPromptPlaceholder}`

### Генерации
- `POST /images/quote`, `POST /videos/quote` (тело как у generate) → цена в кредитах. Звать с дебаунсом при изменении формы.
- `POST /images/generate`, `POST /videos/generate` — **тратят кредиты**. Пример тела: `{modelSlug, prompt, aspectRatio, …}` + id загруженных файлов.
- Загрузки (multipart `file`): `POST /images/uploads/source`, `/videos/uploads/source`, `/videos/uploads/video`, `/videos/uploads/audio`, `/references` (+`projectId`).
- `GET /images?page&pageSize&projectId`, `GET /videos?page&pageSize&projectId&draft` → `{items, page, pageSize, total, hasMore}`
- `GET /images/:id`, `GET /videos/:id` → `{id, status:"pending|processing|completed|failed", stage, prompt, modelSlug, aspectRatio, durationSeconds, outputs:[{url,width,height,bytes,durationSeconds,thumbnailUrl}], errorMessage, createdAt, startedAt, completedAt, progress, etaSeconds, draft, draftId}`. Готовность — опрос каждые 2–3 с, отдельного realtime-канала нет.
- Черновики видео: `POST /videos/:id/finalize/quote`, `POST /videos/:id/finalize`.
- `DELETE /images/:id`, `DELETE /videos/:id`, `POST|DELETE /images/:id/share`.

### Library и проекты
- `GET /projects` → `[{id,name,isDefault,lastUsedAt}]`; `POST /projects {name}`, `PATCH /projects/:id`, `DELETE /projects/:id`
- `GET /references?projectId&limit` → `{items:[{id,kind,url,thumbnailUrl,mimeType,width,height,durationSeconds,createdAt}], nextCursor}`; `GET /references/counts?projectId`
- `POST /library/delete {items}`, `POST /library/move {items, projectId}`
- Медиа на `https://cdn.nxor.ai/…`.

### Чат (SSE)
- `GET /chat/sessions?page&pageSize` → `{items:[{id,title,createdAt,updatedAt}], total, hasMore}`
- `GET /chat/sessions/:id` → `{session, messages:[{id, role, content, attachments[], modelSlug, answeredBy{name,provider}, tier, generationRefs:[{kind,prompt,modelSlug,generationId}], proposals:[…], createdAt}]}`
- Отправка: `POST /chat/sessions/:id/messages` (новый чат — `POST /chat/messages`), тело
  `{tier, content, attachments:[url], documents:[…], files:[{url,name}], promptReview:true}` (+`geniusModel` для genius). Ответ — `text/event-stream`, блоки разделены пустой строкой, строки `event:` и `data:` (JSON):
  - `start` `{sessionId, messageId}`
  - `delta` `{text}` — дописывать к ответу
  - `status` `{stage, detail?}` — stage ∈ thinking, searching, generating, generating_image, generating_video, model_selected, reasoning, writing_prompt, routing, running_code, reading_link, waiting, searching_presets; detail `{kind, role, name, provider, switched, theme, seconds}`
  - `tool` — ссылка на запущенную генерацию `{kind, generationId, prompt, modelSlug, credits, aspectRatio}` → создать плитку и опрашивать `/images|videos/:id`
  - `tool_error` `{kind, code, message, details}`
  - `proposal` — карточка «запустить генерацию?»; `proposal_update` `{proposalId, status:"dismissed"}`
  - `preset_card`, `preset_card_update`, `file` `{url, name, mimeType, sizeBytes}`
  - `done` — итог `{…, proposals?, presetCards?, files?, confirm?{low,high}}`; после него закрыть поток
  - `error` `{generationRefs}`
  - Таймаут простоя 60 с. Отмена: `POST /chat/sessions/:id/cancel`.
- Предложения: `POST /chat/sessions/:sid/proposals/:pid/submit` (**тратит кредиты**), `…/dismiss`. Пресет-карточки: `…/preset-cards/:cid/run`, `…/dismiss`.
- Вложения: `POST /chat/uploads/attachment`, `POST /chat/uploads/file` (multipart `file`).
- `DELETE /chat/sessions/:id`.

### Прочее
- `POST /prompts/enhance` — кнопка «AI PROMPT».
- `GET|PATCH|DELETE /memory`, `GET /referrals/me`, `GET /oauth/grants`.

## План

| Этап | Содержание | Оценка |
|---|---|---|
| 0 | Проект Xcode в `~/Developer/nxor-ios`, git, схема, сборка на симуляторе | 15 мин |
| 1 | Дизайн-система: цвета, шрифты, скошенная форма (Shape), кнопки, чипы, поля, сегменты, sheet, градиентный текст, скелетон, превью-каталог компонентов | 1 ч |
| 2 | Networking: модели Codable по схемам выше, APIClient (cookie, 401→refresh), SSE-парсер, мок-фикстуры, `useMocks` | 1,5 ч |
| 3 | Экраны 1–14 на моках, навигация, состояния загрузки/пусто/ошибка | 3–4 ч |
| 4 | Реальный API: вход → чтение (me, чаты, библиотека, пресеты, модели, quote) → чат-стрим → генерации (только с согласия) | 2–3 ч |
| 5 | PhotosPicker, сохранение в Фото, шаринг, AVPlayer, хаптики, иконка, launch screen | 1–2 ч |
| 6 | (Опционально) TestFlight | 1 ч + ревью |

Скриншоты экранов сайта прилагаются отдельно — сверяй вёрстку по ним.
