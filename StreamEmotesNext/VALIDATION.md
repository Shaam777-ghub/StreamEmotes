# Проверка версии 0.1 — 2 ноября 2026

Исходники загружены в ветку `streamemotes-next` репозитория Shaam777-ghub/StreamEmotes.

## Подтверждено GitHub Actions

[Успешный запуск 41403606477](https://github.com/Shaam777-ghub/StreamEmotes/actions/runs/41403606477), commit `3b0d4eb7352c41a2f612b2dcb344ec02349eeda8`:

- XcodeGen сгенерировал Xcode-проект.
- Xcode успешно собрал Debug для iOS Simulator и Release для iPhone без подписи.
- Проверено наличие Web/index.html и Web/app.js внутри собранного приложения.
- Проверка синтаксиса JavaScript и 6 модульных тестов — успешно.
- UI-тест в Chromium — успешно: лента, чат, paint, экранирование текста, подтверждённая API отправка, удаление сообщений, палитра, настройки, ширина мобильного интерфейса. Ответы API и WebSocket в тесте синтетические; людям сообщения не отправлялись.
- Сохранён артефакт StreamEmotesNext-Simulator.

После первого запуска добавлена поддержка всех четырёх ориентаций для универсального iPhone/iPad проекта, чтобы устранить предупреждение Xcode. Актуальный результат повторной сборки смотрите в [Actions](https://github.com/Shaam777-ghub/StreamEmotes/actions?query=branch%3Astreamemotes-next).

## Реальные публичные API

Проверены успешные JSON-ответы 7TV global/channel emotes, BetterTTV global/channel emotes и badges. Запрос приложения к 7TV v4 GraphQL получил выбранные paint и badge реального публичного пользователя; данные paint успешно преобразованы в CSS.

## Пока не проверено

- Запуск собранного приложения на iOS Simulator или физическом iPhone.
- OAuth-вход Twitch, обновление токена, персональные каналы и реальная отправка сообщений: нужен Client ID и вход пользователя.
- Keychain и сетевой мост на устройстве.
- Реальный Twitch Player в iOS WebKit: нужен HTTPS-хостинг.
- Apple signing, IPA для установки и TestFlight.

Успешная компиляция и UI-тесты не заменяют проверку реальной трансляции и чата на iPhone.
