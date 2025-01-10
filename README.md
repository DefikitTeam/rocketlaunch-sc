<h1 align="center">🤖 DeFiKit - Mother Of Tokens</h1>

<img align="right" width="35%" src="https://github.com/bot-base/telegram-bot-template/assets/26162440/c4371683-3e99-4b1c-ae8e-11ccbea78f4b">

MotherOfTokens is a tool designed to simplify the management of your cryptocurrency token. Developed with the [grammY](https://grammy.dev/) bot framework and ...more.

## Features

- **Create and Deploy Tokens**: Easily establish your own token with customizable features.
- **Tokenize Assets**: Generate tokens representing real-world assets or digital goods.
- **Add Liquidity**: Inject funds into your token's pool to facilitate trading.
- **Transfer Tokens**: Send and receive your tokens seamlessly within the platform.

## Usage

Follow these steps to set up and run your bot using this template:

1. **Environment Variables Setup**
    
    Create an environment variables file by copying the provided example file:
     ```bash
     cp .env.example .env
     ```
    Open the newly created `.env` file and set the `BOT_TOKEN` environment variable.

3. **Launching the Bot**
    
    You can run your bot in both development and production modes.

    **Development Mode:**
    
    Install the required dependencies:
    ```bash
    pnpm install
    ```
    Run migrations:
    ```bash
    pnpm run prisma:migrate
    ```
    Start the bot in watch mode (auto-reload when code changes):
    ```bash
    pnpm run dev
    ```

   **Production Mode:**
    
    Install only production dependencies (no development dependencies):
    ```bash
    pnpm install --prod
    ```
    
    Set the `NODE_ENV` environment variable to "production" in your `.env` file. Also, make sure to update `BOT_WEBHOOK` with the actual URL where your bot will receive updates.
    ```dotenv
    NODE_ENV=production
    BOT_WEBHOOK=<your_webhook_url>
    ```
    
    Run migrations:
    ```bash
    pnpm run prisma:deploy
    pnpm run prisma:generate
    ```

    Start the bot in production mode:
    ```bash
    pnpm start
    # or
    pnpm run start:force # if you want to skip type checking
    ```

### List of Available Commands

- `pnpm run lint` — Lint source code.
- `pnpm run format` — Format source code.
- `pnpm run typecheck` — Run type checking.
- `pnpm run dev` — Start the bot in development mode.
- `pnpm run start` — Start the bot.
- `pnpm run start:force` — Starts the bot without type checking.
- `pnpm run prisma:migrate` — Migrations (Generate migration script + Apply migration script + generate Prisma Client)
- `pnpm run prisma:reset` — Drop database schema + Apply migration script + seeding.
- `pnpm run prisma:generate` — Generate Prisma Client
- `pnpm run prisma:seed` — Seeding.
- `pnpm run prisma:deploy` — Migrations on production.

## Environment Variables

<table>
<thead>
  <tr>
    <th>Variable</th>
    <th>Type</th>
    <th>Description</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td>NODE_ENV</td>
    <td>String</td>
    <td>Specifies the application environment. (<code>development</code> or <code>production</code>)</td>
  </tr>
  <tr>
    <td>BOT_TOKEN</td>
    <td>
        String
    </td>
    <td>
        Telegram Bot API token obtained from <a href="https://t.me/BotFather">@BotFather</a>.
    </td>
  </tr>
    <tr>
    <td>DATABASE_URL</td>
    <td>
        String
    </td>
    <td>
        Database connection.
    </td>
  </tr>
    <tr>
    <td>LOG_LEVEL</td>
    <td>
        String
    </td>
    <td>
        <i>Optional.</i>
        Specifies the application log level. <br/>
        For example, use <code>info</code> for general logging. View the <a href="https://github.com/pinojs/pino/blob/master/docs/api.md#level-string">Pino documentation</a> for more log level options. <br/>
        Defaults to <code>info</code>.
    </td>
  </tr>
  <tr>
    <td>BOT_MODE</td>
    <td>
        String
    </td>
    <td>
        <i>Optional.</i>
        Specifies method to receive incoming updates. (<code>polling</code> or <code>webhook</code>)
        Defaults to <code>polling</code>.
    </td>
  </tr>
  <tr>
    <td>BOT_WEBHOOK</td>
    <td>
        String
    </td>
    <td>
        <i>Optional in <code>polling</code> mode.</i>
        Webhook endpoint URL, used to configure webhook in <b>production</b> environment.
    </td>
  </tr>
  <tr>
    <td>BOT_SERVER_HOST</td>
    <td>
        String
    </td>
    <td>
        <i>Optional.</i> Specifies the server hostname. <br/>
        Defaults to <code>0.0.0.0</code>.
    </td>
  </tr>
  <tr>
    <td>BOT_SERVER_PORT</td>
    <td>
        Number
    </td>
    <td>
        <i>Optional.</i> Specifies the server port. <br/>
        Defaults to <code>80</code>.
    </td>
  </tr>
  <tr>
    <td>BOT_ALLOWED_UPDATES</td>
    <td>
        Array of String
    </td>
    <td>
        <i>Optional.</i> A JSON-serialized list of the update types you want your bot to receive. See <a href="https://core.telegram.org/bots/api#update">Update</a> for a complete list of available update types. <br/>
        Defaults to an empty array (all update types except <code>chat_member</code>).
    </td>
  </tr>
  <tr>
    <td>BOT_ADMINS</td>
    <td>
        Array of Number
    </td>
    <td>
        <i>Optional.</i> 
        Administrator user IDs. 
        Use this to specify user IDs that have special privileges, such as executing <code>/setcommands</code>. <br/>
        Defaults to an empty array.
    </td>
  </tr>
</tbody>
</table>