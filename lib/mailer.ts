/** Transactional email. Logs in development; posts to the provider when an API key is set. */
export interface Mailer {
  send(message: { to: string; subject: string; text: string }): Promise<void>;
}

class ConsoleMailer implements Mailer {
  async send(message: { to: string; subject: string; text: string }) {
    console.info(`[mail] to=${message.to} subject="${message.subject}"`);
  }
}

class HttpMailer implements Mailer {
  constructor(
    private readonly endpoint: string,
    private readonly apiKey: string,
  ) {}

  async send(message: { to: string; subject: string; text: string }) {
    const res = await fetch(this.endpoint, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${this.apiKey}` },
      body: JSON.stringify({ from: "Shelf <hello@shelfapp.com>", ...message }),
    });
    if (!res.ok) throw new Error(`Mail provider responded ${res.status}`);
  }
}

export const mailer: Mailer =
  process.env.MAIL_API_KEY && process.env.MAIL_API_URL
    ? new HttpMailer(process.env.MAIL_API_URL, process.env.MAIL_API_KEY)
    : new ConsoleMailer();
