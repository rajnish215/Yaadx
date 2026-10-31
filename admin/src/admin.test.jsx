import React from "react";
import { test, expect, vi, beforeEach, afterEach } from "vitest";
import {
  render,
  screen,
  fireEvent,
  waitFor,
  cleanup,
} from "@testing-library/react";
const mocks = vi.hoisted(() => ({
  user: {
    uid: "test-admin",
    email: "admin@example.test",
    emailVerified: true,
    reload: async () => {},
    getIdToken: async () => "test-token",
  },
  callback: null,
}));
vi.mock("./firebase", () => ({
  auth: {
    get currentUser() {
      return mocks.user;
    },
  },
  persistenceReady: Promise.resolve(),
}));
vi.mock("firebase/auth", () => ({
  onAuthStateChanged: (_auth, cb) => {
    mocks.callback = cb;
    cb(mocks.user);
    return () => {};
  },
  signOut: async () => {
    mocks.user = null;
    mocks.callback(null);
  },
  signInWithEmailAndPassword: vi.fn(),
  createUserWithEmailAndPassword: vi.fn(),
  sendEmailVerification: vi.fn(),
  sendPasswordResetEmail: vi.fn(),
}));
import { App, upcomingRows } from "./main";
const totals = {
  users: 1,
  reminders: 2,
  subscriptions: 0,
  tickets: 0,
  announcements: 0,
  reads: 0,
  ai_success: 0,
  ai_failed: 0,
  new_users: 1,
};
const dashboard = {
  totals,
  growth: [{ label: "Oct", value: 1 }],
  plans: [{ name: "free", value: 1 }],
  ticketStatus: [],
  recent: [],
  activity: [],
  upcoming: [],
};
let calls = [];
beforeEach(() => {
  mocks.user = {
    uid: "test-admin",
    email: "admin@example.test",
    emailVerified: true,
    reload: async () => {},
    getIdToken: async () => "test-token",
  };
  calls = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (path, options) => {
      calls.push({ path, options });
      let data = {};
      const base=path.split("?")[0];
      if (base.endsWith("/me")) data = { email: "admin@example.test" };
      else if (base.endsWith("/dashboard")) data = dashboard;
      else if ((path.includes("/users?")||path.includes("/subscriptions?")))
        data = {
          rows: [
            {
              uid: "user1",
              email: "user@example.test",
              display_name: "<img onerror=alert(1)>",
              status: "active",
              plan: "free",
            },
          ],
          total: 1,
        };
      else if (base.endsWith("/announcements"))
        data = {
          rows: [
            {
              id: "draft1",
              title: "Our draft",
              body: "Draft contents",
              status: "draft",
              version: 1,
              reads: 0,
            },
          ],
        };
      else if (path.includes("/tickets?") || path.includes("/activity?"))
        data = { rows: [], total: 0 };
      else if (base.endsWith("/settings"))
        data = {
          version: 1,
          support_email: "",
          maintenance_message: "",
          security: {
            adminEmails: ["admin@example.test"],
            databaseIsolation: "PostgreSQL RLS",
            aiConfigured: true,
          },
        };
      if(base.endsWith('/system'))data={source:'Neon PostgreSQL',counts:{real_users:1,test_users:4},database:'connected',databaseLatencyMs:5,uptimeSeconds:100};
      if(base.endsWith('/backups'))data={rows:[]};
      return { ok: true, json: async () => data };
    }),
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
test("all navigation sections load without stale response shape crashes", async () => {
  render(<App />);
  await screen.findByText("Total Users");
  for (const name of [
    "User Management",
    "Subscription Management",
    "Notification Management",
    "Support & Feedback",
    "Analytics & Reports",
    "Settings & Security",
    "Send Announcement",
    "View App Logs",
    "Backup Data",
    "Dashboard",
  ]) {
    fireEvent.click(screen.getByRole("button", { name, exact: true }));
    if (name === "Dashboard") await screen.findByText("Total Users");
    else await screen.findByRole("heading", { name, exact: true });
    await waitFor(() =>
      expect(screen.queryByText("Loading live information…")).toBeNull(),
    );
  }
  expect(calls.some((c) => c.path.includes("/settings"))).toBe(true);
});
test("untrusted user names render as text and publication requires review", async () => {
  render(<App />);
  await screen.findByText("Total Users");
  fireEvent.click(
    screen.getByRole("button", { name: "User Management", exact: true }),
  );
  expect(await screen.findByText("<img onerror=alert(1)>")).toBeTruthy();
  expect(document.querySelector("img")).toBeNull();
  fireEvent.click(
    screen.getByRole("button", {
      name: "Notification Management",
      exact: true,
    }),
  );
  fireEvent.click(
    await screen.findByRole("button", { name: "Review & publish" }),
  );
  expect(calls.filter((c) => c.options.method === "PATCH")).toHaveLength(0);
  expect(screen.getByRole("dialog")).toBeTruthy();
  fireEvent.click(screen.getByRole("button", { name: "Publish to app inbox" }));
  await waitFor(() =>
    expect(calls.filter((c) => c.options.method === "PATCH")).toHaveLength(1),
  );
  expect(
    JSON.parse(calls.find((c) => c.options.method === "PATCH").options.body),
  ).toEqual({ status: "published", baseVersion: 1 });
});
test("denied admins never load dashboard data", async () => {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => ({
      ok: false,
      json: async () => ({ error: "admin_required" }),
    })),
  );
  render(<App />);
  await screen.findByText(/not the approved admin account/);
  expect(screen.queryByText("Total Users")).toBeNull();
  expect(fetch).toHaveBeenCalledTimes(1);
});
test("empty or malformed event dates are excluded and yearly birthdays advance", () => {
  const rows = upcomingRows([
    { id: "bad", date: "invalid" },
    { id: "old", date: "1990-01-01", repeat_yearly: false },
    { id: "yearly", date: "2000-02-29", repeat_yearly: true },
  ]);
  expect(rows).toHaveLength(1);
  expect(rows[0].id).toBe("yearly");
  expect(rows[0].next.getMonth()).toBe(1);
});

test('login is restricted to the fixed admin email without account creation',async()=>{
 mocks.user=null;render(<App/>);
 const email=await screen.findByLabelText('Admin email');
 expect(email.value).toBe('ankitkr7488.01@gmail.com');expect(email.readOnly).toBe(true);
 expect(screen.queryByText('Pehli baar? Account banao')).toBeNull();
});
test('approved password login does not require email verification',async()=>{
 mocks.user.emailVerified=false;render(<App/>);await screen.findByText('Total Users');
 expect(screen.queryByText('Send verification email')).toBeNull();
});

 test('access check shows loading without a sign-out flash', async () => {
   const { AccessGate } = await import('./AccessGate');
   let finish;
   const pending = new Promise(resolve => { finish = resolve; });
   const allowed = vi.fn();
   render(<AccessGate user={mocks.user} checkAdmin={() => pending} onAllowed={allowed} errorMessage={e=>e.message}/>);
   await screen.findByText('Opening your dashboard…');
   expect(screen.queryByRole('button', {name: 'Sign out'})).toBeNull();
   finish();
   await waitFor(()=>expect(allowed).toHaveBeenCalledTimes(1));
 });
 test('subscription filter and test-account scope are sent to backend', async () => {
   render(<App/>);
   await screen.findByText('Total Users');
   fireEvent.click(screen.getByRole('button',{name:'Subscription Management',exact:true}));
   const filter=await screen.findByRole('combobox');
   fireEvent.change(filter,{target:{value:'expiring'}});
   await waitFor(()=>expect(calls.some(c=>c.path.includes('/subscriptions?')&&c.path.includes('status=expiring'))).toBe(true));
   fireEvent.click(screen.getByRole('checkbox'));
   await waitFor(()=>expect(calls.some(c=>c.path.includes('/subscriptions?')&&c.path.includes('includeTest=1'))).toBe(true));
 });

test('upcoming events respect server dates and future start years',()=>{
 const year=new Date().getFullYear()+2;
 const rows=upcomingRows([
  {id:'server',date:'2000-02-29',next_date:`${year}-02-28`,repeat_yearly:true},
  {id:'future',date:`${year}-11-01`,repeat_yearly:true},
 ]);
 expect(rows.find(r=>r.id==='server').next.getFullYear()).toBe(year);
 expect(rows.find(r=>r.id==='server').next.getDate()).toBe(28);
 expect(rows.find(r=>r.id==='future').next.getFullYear()).toBe(year);
});
