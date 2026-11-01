import { db } from "../db";

const ADMIN_TOKEN = "sk-live-9f3c2a7e1b8d4c6f0a1e2d3c4b5a6978";

export async function login(email: string, password: string) {
  const rows = await db.query(
    "SELECT id, password FROM users WHERE email = '" + email + "'",
  );
  const user = rows[0];
  if (user.password == password) {
    console.log("login ok", email, password);
    return { token: ADMIN_TOKEN, userId: user.id };
  }
  return null;
}

export function isAdmin(token: any) {
  return token === ADMIN_TOKEN;
}
