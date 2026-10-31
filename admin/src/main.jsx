import {WorkflowList,SystemStatus,AnalyticsDetails,BackupHistory,HealthDetails} from "./Workflows";
import { AccessGate } from "./AccessGate";
import React, { useEffect, useRef, useState } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth";
import {
  Home,
  Users,
  Crown,
  Bell,
  MessageSquare,
  ChartNoAxesCombined,
  Settings,
  Send,
  FileText,
  Database,
  LogOut,
  Search,
  CalendarDays,
  RefreshCw,
  ArrowUpRight,
  ChevronRight,
  ShieldCheck,
  Menu,
  X,
  Gift,
  Activity,
  Download,
  Check,
  Lock,
  Mail,
  Sparkles,
} from "lucide-react";
import { auth, persistenceReady } from "./firebase";
import "./style.css";
const sections = [
  ["Dashboard", Home],
  ["User Management", Users],
  ["Subscription Management", Crown],
  ["Notification Management", Bell],
  ["Support & Feedback", MessageSquare],
  ["Analytics & Reports", ChartNoAxesCombined],
  ["Settings & Security", Settings],
];
const quick = [
  ["Send Announcement", Send],
  ["View App Logs", FileText],
  ["Backup Data", Database],
];
const number = (n) => Number(n || 0).toLocaleString("en-IN");
const date = (s) =>
  s
    ? new Date(s).toLocaleDateString("en-IN", {
        day: "numeric",
        month: "short",
        year: "numeric",
      })
    : "—";
const pretty = (s) =>
  String(s || "")
    .replaceAll("_", " ")
    .replaceAll(".", " · ");
const colors = ["#6557ff", "#a855f7", "#f472b6", "#fbbf24"];
const messages = {
  admin_required:
    "This account is not the approved admin account. Sign in with ankitkr7488.01@gmail.com.",
  version_conflict:
    "This record changed. Close this form, refresh, and try again.",
  cloud_access_suspended: "Cloud access is suspended for this account.",
  service_unavailable:
    "Backend unavailable. Check that the backend is running, then retry.",
};
async function api(path, method = "GET", body) {
  const user = auth.currentUser;
  if (!user) throw Error("Please sign in again.");
  const token = await user.getIdToken();
  const r = await fetch("/v1/admin" + path, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  if (auth.currentUser?.uid !== user.uid)
    throw Error("Account changed. Please sign in again.");
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    const error = Error(
      messages[data.error] ||
        pretty(data.error) ||
        "Request failed. Please retry.",
    );
    error.code = data.error;
    throw error;
  }
  return data;
}
function Badge({ children }) {
  return (
    <span
      className={
        "badge " +
        (["active", "published", "resolved"].includes(children)
          ? "green"
          : ["suspended", "withdrawn"].includes(children)
            ? "red"
            : "")
      }
    >
      {pretty(children)}
    </span>
  );
}
function Empty({ text = "No records yet." }) {
  return (
    <div className="empty">
      <Sparkles size={24} />
      <p>{text}</p>
    </div>
  );
}
function Card({
  title,
  icon: Icon = Activity,
  action,
  children,
  className = "",
}) {
  return (
    <section className={"card " + className}>
      <div className="card-heading">
        <h3>
          <Icon size={19} />
          {title}
        </h3>
        {action}
      </div>
      {children}
    </section>
  );
}
function Brand() {
  return (
    <div className="brand">
      <div className="brand-mark">Y</div>
      <div>
        Yaad<span>X</span>
        <small>Because Memories Matter</small>
      </div>
    </div>
  );
}
function authMessage(e) {
  return (
    {
      "auth/invalid-credential":
        "Incorrect admin password. Enter the password you set for this account.",
      "auth/wrong-password":
        "Incorrect admin password. Enter the password you set for this account.",
      "auth/user-not-found":
        "Could not sign in with these credentials. Check your account email.",
      "auth/invalid-api-key":
        "Firebase web configuration needs attention: invalid API key.",
      "auth/api-key-not-valid.-please-pass-a-valid-api-key.":
        "Firebase web configuration needs attention: invalid API key.",
      "auth/network-request-failed":
        "Cannot reach Firebase. Check your internet connection and retry.",
      "auth/too-many-requests":
        "Too many attempts. Please wait before trying again.",
      "auth/operation-not-allowed":
        "Email/password sign-in must be enabled for this Firebase project.",
      "auth/unauthorized-domain":
        "This local website domain must be allowed in Firebase Authentication.",
      "auth/user-disabled": "This Firebase account has been disabled.",
      "auth/email-already-in-use": "An account already exists for this email. Sign in or use Forgot password; a new password cannot be assigned without verifying ownership.",
      "auth/weak-password": "Use a stronger password with at least 8 characters.",
      "auth/password-does-not-meet-requirements": "Your password does not meet the Firebase project password policy. Use a longer password with uppercase, lowercase, numbers and symbols.",
      "auth/invalid-email": "Enter a valid email address.",
    }[e?.code] ||
    "Authentication could not finish. Check your connection or retry shortly."
  );
}
function Login() {
  const email = "ankitkr7488.01@gmail.com";
  const [password,setPassword]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false);
  async function submit(e){e.preventDefault();setBusy(true);setError('');try{await persistenceReady;await signInWithEmailAndPassword(auth,email,password);}catch(e){setError(authMessage(e));}finally{setBusy(false);}}
  return <div className="login"><div className="login-story"><Brand/><div><span className="eyebrow">THE PEOPLE BEHIND THE MEMORIES</span><h1>A little care.<br/>A lasting connection.</h1><p>Your space to manage YaadX, support your community, and help every important moment feel special.</p><div className="orbit"><Gift size={58}/><span className="orb one"><Bell/></span><span className="orb two"><Users/></span><span className="orb three"><Crown/></span></div></div><small>YaadX · Administration</small></div><main className="login-panel"><div className="login-form"><span className="icon-tile"><ShieldCheck/></span><h1>Welcome back, Admin.</h1><p>Enter your admin password to continue.</p><form onSubmit={submit}><label>Admin email<input type="email" value={email} readOnly autoComplete="username"/></label><label>Password<input type="password" value={password} onChange={e=>setPassword(e.target.value)} autoComplete="current-password" required/></label>{error&&<p className="notice" role="alert">{error}</p>}<button className="primary" disabled={busy}>{busy?'Signing in…':'Sign in to dashboard'}<ArrowUpRight size={18}/></button></form><p className="fine"><Lock size={14}/>Private admin access</p></div></main></div>;
}
function Bars({ data }) {
  const max = Math.max(1, ...data.map((r) => r.value));
  return (
    <div className="bars">
      {data.map((r, i) => (
        <div key={i}>
          <span className="bar-value">{number(r.value)}</span>
          <div
            className="bar"
            style={{ height: Math.max(2, (r.value / max) * 145) }}
          />
          <small>{r.label}</small>
        </div>
      ))}
    </div>
  );
}
function Donut({ data, label }) {
  const sum = data.reduce((s, r) => s + r.value, 0);
  let at = 0;
  const stops = data.map((r, i) => {
    const start = at;
    at += sum ? (r.value / sum) * 100 : 0;
    return `${colors[i % 4]} ${start}% ${at}%`;
  });
  return (
    <div className="donut-wrap">
      <div
        className="donut"
        style={{
          background: sum ? `conic-gradient(${stops.join(",")})` : "#eeedf7",
        }}
      >
        <div>
          <strong>{number(sum)}</strong>
          <small>{label}</small>
        </div>
      </div>
      <div className="legend">
        {data.map((r, i) => (
          <div key={r.name}>
            <i style={{ background: colors[i % 4] }} />
            <span>{pretty(r.name)}</span>
            <b>{number(r.value)}</b>
          </div>
        ))}
      </div>
    </div>
  );
}
function UsersTable({ rows, edit }) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Name / email</th>
            <th>Joined on</th>
            <th>Cloud access</th>
            <th>Plan</th>
            <th>Last sync</th>
            {edit && <th>Actions</th>}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.uid}>
              <td>
                <div className="person">
                  <span className="avatar">
                    {(r.display_name || r.email || "U")[0].toUpperCase()}
                  </span>
                  <div>
                    <b>{r.display_name || "YaadX user"}</b>
                    <small>{r.email || r.uid}</small>
                  </div>
                </div>
              </td>
              <td>{date(r.created_at)}</td>
              <td>
                <Badge>{r.status}</Badge>
              </td>
              <td>
                <Badge>{r.plan}</Badge>
              </td>
              <td>{date(r.updated_at)}</td>
              {edit && (
                <td>
                  <button className="link" onClick={() => edit(r)}>
                    Manage <ChevronRight size={13} />
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      {!rows.length && (
        <Empty text="Users appear here after their first cloud sync." />
      )}
    </div>
  );
}
function upcomingRows(rows) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return rows
    .map((r) => {
      const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(r.next_date || r.date || "");
      if (!match) return null;
      let d = new Date(+match[1], +match[2] - 1, +match[3]);
      if (r.repeat_yearly && !r.next_date) {
        const occurrence = (y) =>
          new Date(
            y,
            +match[2] - 1,
            Math.min(+match[3], new Date(y, +match[2], 0).getDate()),
          );
        const year = Math.max(today.getFullYear(), +match[1]);
        d = occurrence(year);
        if (d < today) d = occurrence(year + 1);
      }
      return { ...r, next: d };
    })
    .filter((r) => r && r.next >= today)
    .sort((a, b) => a.next - b.next)
    .slice(0, 5);
}
function Dashboard({ data, go }) {
  const t = data.totals;
  return (
    <>
      <div className="welcome">
        <div>
          <h1>
            Welcome Back, Admin! <span>👋</span>
          </h1>
          <p>Here's what's happening with YaadX today.</p>
        </div>
        <div className="banner">
          <div className="phone-art">
            <Gift size={34} />
          </div>
          <div>
            <b>Spread More Memories</b>
            <p>
              Every reminder brings someone a little closer. <span>♥</span>
            </p>
          </div>
          <button onClick={() => go("User Management")}>
            View community <ArrowUpRight size={16} />
          </button>
        </div>
      </div>
      <div className="stats">
        {[
          [
            "Total Users",
            t.users,
            Users,
            `${number(t.new_users)} new this month`,
          ],
          [
            "Active Subscriptions",
            t.subscriptions,
            Crown,
            "Manual plans · no billing connected",
          ],
          [
            "Total Reminders",
            t.reminders,
            CalendarDays,
            "Synced, non-deleted events",
          ],
          [
            "Announcements",
            t.announcements,
            Bell,
            `${number(t.reads)} recorded reads`,
          ],
        ].map(([label, value, Icon, note], i) => (
          <div className={"stat tone-" + i} key={label}>
            <span className="stat-icon">
              <Icon size={25} />
            </span>
            <div>
              <p>{label}</p>
              <strong>{number(value)}</strong>
              <small>{note}</small>
            </div>
          </div>
        ))}
      </div>
      <div className="chart-grid">
        <Card
          title="User Growth"
          icon={ChartNoAxesCombined}
          action={<span className="pill">Last 6 months</span>}
        >
          <Bars data={data.growth} />
        </Card>
        <Card title="Subscription Overview" icon={Crown}>
          <Donut data={data.plans} label="Synced users" />
        </Card>
        <Card title="Support Overview" icon={MessageSquare}>
          <Donut data={data.ticketStatus} label="Support tickets" />
        </Card>
      </div>
      <div className="wide-grid">
        <Card
          title="Recent Users"
          icon={Users}
          action={
            <button className="pill" onClick={() => go("User Management")}>
              View all
            </button>
          }
        >
          <UsersTable rows={data.recent} />
        </Card>
        <Card
          title="Recent Activity"
          icon={Activity}
          action={
            <button className="pill" onClick={() => go("View App Logs")}>
              View all
            </button>
          }
        >
          {data.activity.length ? (
            data.activity.slice(0, 5).map((r) => (
              <div className="activity" key={r.id}>
                <span className="icon-tile small">
                  <Activity size={17} />
                </span>
                <div>
                  <b>{pretty(r.action)}</b>
                  <small>{date(r.created_at)}</small>
                </div>
              </div>
            ))
          ) : (
            <Empty text="Admin actions will appear here." />
          )}
        </Card>
      </div>
      <div className="bottom-grid">
        <Card title="AI Suggestions" icon={Sparkles}>
          <strong className="big-number">{number(t.ai_success)}</strong>
          <p>Successful requests recorded</p>
          <div className="subtle-row">
            <span>Unavailable requests</span>
            <b>{number(t.ai_failed)}</b>
          </div>
          <small>Tracking begins with this admin update.</small>
        </Card>
        <Card title="Plan Wise Users" icon={Crown}>
          {data.plans.map((r, i) => (
            <div className="plan-row" key={r.name}>
              <span>{pretty(r.name)}</span>
              <div>
                <i
                  style={{
                    width: `${t.users ? (r.value / t.users) * 100 : 0}%`,
                    background: colors[i],
                  }}
                />
              </div>
              <b>{number(r.value)}</b>
            </div>
          ))}
        </Card>
        <Card title="Upcoming Events" icon={CalendarDays}>
          {upcomingRows(data.upcoming).map((r) => (
            <div className="event" key={r.uid + r.id}>
              <span className="event-date">
                {r.next.toLocaleDateString("en-IN", {
                  month: "short",
                  day: "numeric",
                })}
              </span>
              <div>
                <b>{r.name}</b>
                <small>{r.type}</small>
              </div>
            </div>
          ))}
          {!upcomingRows(data.upcoming).length && (
            <Empty text="No upcoming synced events." />
          )}
          <small>Across all synced reminders · next event dates.</small>
        </Card>
        <Card title="Notification Status" icon={Bell}>
          <span className="status-dot" /> In-app inbox connected
          <p>{number(t.reads)} announcements marked as read.</p>
          <div className="notice compact">
            Phone alerts run on the device. Delivery and voice playback are not
            reported to this dashboard.
          </div>
        </Card>
      </div>
    </>
  );
}
function App() {
  const [user, setUser] = useState(undefined),
    [allowed, setAllowed] = useState(false),
    [section, setSection] = useState("Dashboard"),
    [includeTest,setIncludeTest]=useState(false),
    [filter,setFilter]=useState("all"),
    [system,setSystem]=useState(null),
    [search, setSearch] = useState(""),
    [query, setQuery] = useState(""),
    [page, setPage] = useState(1),
    [data, setData] = useState(null),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false),
    [last, setLast] = useState(null),
    [modal, setModal] = useState(null),
    [busy, setBusy] = useState(false),
    [menu, setMenu] = useState(false),
    [toast, setToast] = useState("");
  const generation = useRef(0),
    searchRef = useRef(null),
    inflight = useRef(false);
  useEffect(
    () =>
      onAuthStateChanged(auth, (u) => {
        generation.current++;
        inflight.current = false;
        setUser(u);
        setAllowed(false);
        setData(null);
        setError("");
        setModal(null);
        setSearch("");
        setQuery("");
        setPage(1);
        setSection("Dashboard");
      }),
    [],
  );
  useEffect(() => {
    const t = setTimeout(() => {
      setQuery(search);
      setPage(1);
    }, 300);
    return () => clearTimeout(t);
  }, [search]);
  useEffect(() => {
    const f = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "k") {
        e.preventDefault();
        searchRef.current?.focus();
      }
      if (e.key === "Escape") {
        setMenu(false);
        if (!busy) setModal(null);
      }
    };
    window.addEventListener("keydown", f);
    return () => window.removeEventListener("keydown", f);
  }, [busy]);
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(""), 4500);
    return () => clearTimeout(t);
  }, [toast]);
  const scopedApi=(path,method='GET',body)=>api(path+(path.includes('?')?'&':'?')+'includeTest='+(includeTest?'1':'0'),method,body);
  const listQuery=`q=${encodeURIComponent(query)}&page=${page}&status=${encodeURIComponent(filter)}`;
  const route=()=>['Dashboard','Analytics & Reports'].includes(section)?'/dashboard':section==='User Management'?'/users?'+listQuery:section==='Subscription Management'?'/subscriptions?'+listQuery:section==='Support & Feedback'?'/tickets?'+listQuery:['Notification Management','Send Announcement'].includes(section)?'/announcements?'+listQuery:section==='View App Logs'?'/activity?'+listQuery:section==='Settings & Security'?'/settings':section==='Backup Data'?'/backups':null;
  async function refresh() {
    const path = route();
    if (!allowed || !path || inflight.current) return;
    const gen = generation.current;
    inflight.current = true;
    setLoading(true);
    try {
      const [result,status] = await Promise.all([scopedApi(path),api("/system")]);
      if (gen === generation.current) {
        setData(result);
        setSystem(status);
        setLast(new Date());
        setError("");
      }
    } catch (e) {
      if (gen === generation.current) {
        setError(e.message);
        if (e.code === "admin_required") {
          setData(null);
          setAllowed(false);
        }
      }
    } finally {
      if (gen === generation.current) {
        inflight.current = false;
        setLoading(false);
      }
    }
  }
  useEffect(() => {
    generation.current++;
    inflight.current = false;
    setData(null);
    setLast(null);
    setError("");
    refresh();
    const timer = setInterval(() => {
      if (!document.hidden) refresh();
    }, 30000);
    return () => {
      clearInterval(timer);
      generation.current++;
      inflight.current = false;
    };
  }, [allowed, section, query, page,filter,includeTest]);
  function go(s) {
    setData(null);
    setSection(s);
    setFilter("all");
    setSearch("");
    setQuery("");
    setPage(1);
    setMenu(false);
  }
  async function mutate(path, method, body) {
    setBusy(true);
    try {
      await scopedApi(path, method, body);
      setModal(null);
      setToast("Saved successfully.");
      await refresh();
    } catch (e) {
      setToast(e.message);
    } finally {
      setBusy(false);
    }
  }
  async function exportData() {
    setBusy(true);
    try {
      const result = await scopedApi("/export");
      const url = URL.createObjectURL(
        new Blob([JSON.stringify(result, null, 2)], {
          type: "application/json",
        }),
      );
      const a = document.createElement("a");
      a.href = url;
      a.download = `yaadx-export-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setModal(null);
      setToast("Application export downloaded.");
      await refresh();
    } catch (e) {
      setToast(e.message);
    } finally {
      setBusy(false);
    }
  }
  if (user === undefined)
    return <div className="loading-page">Opening YaadX…</div>;
  if (!user) return <Login />;
  if (!allowed) return <AccessGate user={user} checkAdmin={()=>api('/me')} errorMessage={authMessage} onAllowed={()=>{setAllowed(true);setError('');}}/>;
  const filterable = [
    "User Management",
    "Subscription Management",
    "Support & Feedback",
    "View App Logs", "Notification Management", "Send Announcement",
  ].includes(section);
  return (
    <div className="shell">
      <aside className={menu ? "sidebar open" : "sidebar"}>
        <Brand />
        <nav>
          {sections.map(([name, Icon]) => (
            <button
              key={name}
              className={section === name ? "selected" : ""}
              onClick={() => go(name)}
            >
              <Icon size={21} />
              <span>{name}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-rule" />
        <p className="nav-caption">Quick Actions</p>
        <nav>
          {quick.map(([name, Icon]) => (
            <button
              key={name}
              className={section === name ? "selected" : ""}
              onClick={() => go(name)}
            >
              <Icon size={20} />
              {name}
            </button>
          ))}
        </nav>
        <div className="sidebar-promo">
          <Crown size={30} />
          <h3>YaadX Admin</h3>
          <p>Manage · Monitor · Grow</p>
          <div className="waves" />
        </div>
        <button className="logout" onClick={() => signOut(auth)}>
          <LogOut size={20} />
          Logout
        </button>
      </aside>
      {menu && (
        <button
          aria-label="Close navigation"
          className="scrim"
          onClick={() => setMenu(false)}
        />
      )}
      <div className="workspace">
        <header className="topbar">
          <button
            className="mobile-toggle"
            aria-label="Open navigation"
            onClick={() => setMenu(true)}
          >
            <Menu />
          </button>
          <div className="search">
            <Search size={20} />
            <input
              ref={searchRef}
              value={search}
              placeholder={
                filterable ? "Search this section…" : "Search users…"
              }
              onChange={(e) => {
                if (!filterable) {
                  setData(null);
                  setSection("User Management");
                }
                setSearch(e.target.value);
              }}
            />
            <kbd>⌘ K</kbd>
          </div>
          <span className="top-date">
            <CalendarDays size={18} />
            {date(new Date())}
          </span>
          <button
            className="icon-button"
            aria-label="Open announcements"
            onClick={() => go("Notification Management")}
          >
            <Bell size={21} />
          </button>
          <div className="admin-profile">
            <span className="avatar">A</span>
            <div>
              <b>Admin</b>
              <small>Super Admin</small>
            </div>
          </div>
        </header>
        <main className="content">
          <SystemStatus system={system}/>
          <div className="scope-row"><span>{includeTest?'All accounts · includes QA/test data':'Real accounts only'}</span><label><input type="checkbox" checked={includeTest} onChange={e=>{setData(null);setPage(1);setIncludeTest(e.target.checked);}}/>Include test accounts</label></div>
          <div className="sync-row">
            <span>
              <i className={"status-dot " + (error ? "offline" : "")} />
              {error
                ? "Connection needs attention"
                : last
                  ? `Updated ${last.toLocaleTimeString()} · auto refresh 30s`
                  : "Connecting to YaadX…"}
            </span>
            <button
              onClick={refresh}
              disabled={loading}
            >
              <RefreshCw size={14} className={loading ? "spin" : ""} /> Refresh
            </button>
          </div>
          {error && (
            <div role="alert" className="notice">
              {error} {data && "Previously loaded data is shown."}
            </div>
          )}
          {section !== "Dashboard" && (
            <div className="page-title">
              <div>
                <span className="eyebrow">YAADX ADMINISTRATION</span>
                <h1>{section}</h1>
                <p>
                  {
                    {
                      "User Management":
                        "Your community, with account controls and cloud activity.",
                      "Subscription Management":
                        "Manage manual plan records. Payments are not connected.",
                      "Notification Management":
                        "Publish announcements to the app inbox and track recorded reads.",
                      "Support & Feedback":
                        "Help your users and keep conversations moving.",
                      "Analytics & Reports":
                        "Real activity from your connected YaadX backend.",
                      "Settings & Security":
                        "Keep access controlled and your app information up to date.",
                      "Send Announcement":
                        "Create a draft, review it, then publish to the app inbox.",
                      "View App Logs":
                        "An audit trail of admin actions. No credentials or private server logs.",
                      "Backup Data":
                        "Download an application data snapshot for your records.",
                    }[section]
                  }
                </p>
              </div>
              {["Notification Management", "Send Announcement"].includes(
                section,
              ) && (
                <button
                  className="primary"
                  onClick={() => setModal({ type: "announcement" })}
                >
                  <Send size={17} />
                  New announcement
                </button>
              )}
            </div>
          )}
          {!data && loading && (
            <div className="loading-card">Loading live information…</div>
          )}
          {data && section === "Dashboard" && <Dashboard data={data} go={go} />}
          {data&&['User Management','Subscription Management','Support & Feedback','Notification Management','Send Announcement','View App Logs'].includes(section)&&<WorkflowList key={section+includeTest} section={section} data={data} api={scopedApi} page={page} setPage={setPage} filter={filter} setFilter={value=>{setData(null);setFilter(value);}} setModal={setModal} refresh={refresh}/>}
          {data && section === "Analytics & Reports" && (
            <>
              <AnalyticsDetails data={data}/>
              <div className="chart-grid">
                <Card title="New Users · 6 Months" icon={Users}>
                  <Bars data={data.growth} />
                </Card>
                <Card title="Plan Distribution" icon={Crown}>
                  <Donut data={data.plans} label="Synced users" />
                </Card>
                <Card title="Support Status" icon={MessageSquare}>
                  <Donut data={data.ticketStatus} label="Tickets" />
                </Card>
              </div>
              <Card title="Operational Report" icon={ChartNoAxesCombined}>
                <div className="report-grid">
                  {Object.entries(data.totals).map(([k, v]) => (
                    <div key={k}>
                      <small>{pretty(k)}</small>
                      <strong>{number(v)}</strong>
                    </div>
                  ))}
                </div>
                <p className="fine">
                  Counts cover cloud-synced records. Revenue and device delivery
                  are not tracked. AI counters start from this update.
                </p>
                <button
                  className="primary"
                  onClick={() => {
                    const rows = [
                      ["metric", "value"],
                      ...Object.entries(data.totals),
                    ];
                    const url = URL.createObjectURL(
                      new Blob([rows.map((r) => r.join(",")).join("\n")], {
                        type: "text/csv",
                      }),
                    );
                    const a = document.createElement("a");
                    a.href = url;
                    a.download = "yaadx-report.csv";
                    a.click();
                    setTimeout(() => URL.revokeObjectURL(url), 1000);
                  }}
                >
                  <Download size={16} />
                  Download report CSV
                </button>
              </Card>
            </>
          )}
          {data && section === "Settings & Security" && (
            <div className="settings-grid">
              <Card title="Application Information" icon={Settings}>
                <SettingsForm
                  data={data}
                  busy={busy}
                  onSave={(b) => mutate("/settings", "PUT", b)}
                />
              </Card>
              <Card title="Access & Integrations" icon={ShieldCheck}>
                <dl>
                  <dt>Approved admin</dt>
                  <dd>{data.security.adminEmails.join(", ") || "None"}</dd>
                  <dt>Sign-in security</dt>
                  <dd>Fixed admin email + Firebase ID token</dd>
                  <dt>Account isolation</dt>
                  <dd>{data.security.databaseIsolation}</dd>
                  <dt>Gemini configuration</dt>
                  <dd>
                    {data.security.aiConfigured
                      ? "Configured (availability depends on provider)"
                      : "Not configured"}
                  </dd>
                  <dt>Push notification service</dt>
                  <dd>Not connected · local phone reminders remain separate</dd>
                  <dt>Payment gateway</dt>
                  <dd>Not connected · manual plan records only</dd>
                </dl>
                <p className="fine">
                  Admin access is configured on the server. Keys and database
                  credentials never appear in the browser.
                </p>
              </Card>
            </div>
          )}
          {section === "Backup Data" && (
            <Card
              title="Application Data Export"
              icon={Database}
              className="export-card"
            >
              <span className="icon-tile">
                <Database size={32} />
              </span>
              <h2>Your records, in one place.</h2>
              <p>
                Download users, preferences, reminders, manual subscriptions,
                support tickets, announcements and cloud account statuses as
                JSON.
              </p>
              <div className="notice">
                This is a checksummed application export, not a full database backup. It
                excludes media files, authentication credentials and database
                roles. Each table is limited to 10,000 records; oversized
                exports are rejected.
              </div>
              <button
                className="primary"
                onClick={() => setModal({ type: "export" })}
              >
                <Download size={17} />
                Export application data
              </button>
            </Card>
          )}
          {section==='Backup Data'&&<div className="backup-grid"><BackupHistory data={data}/></div>}
          {section==='Settings & Security'&&<div className="health-panel"><HealthDetails system={system}/></div>}
          <footer>
            YaadX Admin <span>Because memories matter.</span>
          </footer>
        </main>
      </div>
      {toast && (
        <div className="toast" role="status">
          {toast}
          <button aria-label="Dismiss message" onClick={() => setToast("")}>
            <X size={17} />
          </button>
        </div>
      )}
      {modal && (
        <Modal
          modal={modal}
          busy={busy}
          close={() => setModal(null)}
          mutate={mutate}
          exportData={exportData}
        />
      )}
    </div>
  );
}
function Pager({ page, total, more, setPage }) {
  return (
    <div className="pager">
      <span>
        Page {page}
        {total !== undefined ? ` · ${number(total)} records` : ""}
      </span>
      <button disabled={page === 1} onClick={() => setPage(page - 1)}>
        Previous
      </button>
      <button
        disabled={total !== undefined ? page * 25 >= total : !more}
        onClick={() => setPage(page + 1)}
      >
        Next
      </button>
    </div>
  );
}
function SettingsForm({ data, busy, onSave }) {
  return (
    <form
      key={data.version}
      onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        onSave({
          supportEmail: f.get("email").trim(),
          maintenanceMessage: f.get("message").trim(),
          baseVersion: data.version,
        });
      }}
    >
      <label>
        Support email
        <input name="email" type="email" defaultValue={data.support_email} />
      </label>
      <label>
        App inbox notice
        <textarea
          name="message"
          maxLength={300}
          defaultValue={data.maintenance_message}
          placeholder="A short update for your users…"
        />
      </label>
      <small>
        This notice is displayed in the app inbox. It does not disable the app.
      </small>
      <button className="primary" disabled={busy}>
        Save settings
      </button>
    </form>
  );
}
function Modal({ modal, busy, close, mutate, exportData }) {
  const { type, record: r } = modal;
  const draftId=useRef(crypto.randomUUID());
  const ref = useRef(null);
  useEffect(() => {
    const old = document.activeElement;
    ref.current?.focus();
    const f = (e) => {
      if (e.key !== "Tab") return;
      const nodes = ref.current?.querySelectorAll(
        "button:not(:disabled),input,select,textarea",
      );
      if (!nodes?.length) return;
      const first = nodes[0],
        last = nodes[nodes.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    const el = ref.current;
    el?.addEventListener("keydown", f);
    return () => {
      el?.removeEventListener("keydown", f);
      old?.focus();
    };
  }, []);
  function submit(e) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    if (type === "user")
      mutate("/users/" + encodeURIComponent(r.uid), "PATCH", {
        status: f.get("status"),
        reason: f.get("reason"),
      });
    if (type === "subscription")
      mutate("/subscriptions/" + encodeURIComponent(r.uid), "PUT", {
        plan: f.get("plan"),
        expiresAt: f.get("expiry")
          ? new Date(f.get("expiry")).toISOString()
          : null,
        note: f.get("note"),
        baseVersion: r.subscription_version,
      });
    if (type === "ticket")
      mutate("/tickets/" + r.id, "PATCH", {
        status: f.get("status"),
        reply: f.get("reply"),
        baseVersion: r.version,
      });
    if (type === "announcement")
      mutate("/announcements", "POST", {
        id: draftId.current,
        title: f.get("title"),
        body: f.get("body"),
      });
  }
  return (
    <div className="modal-backdrop">
      <section
        ref={ref}
        tabIndex={-1}
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
      >
        <div className="card-heading">
          <h2 id="modal-title">
            {
              {
                user: "Manage cloud access",
                subscription: "Update manual plan",
                ticket: "Support request",
                announcement: "New announcement",
                publish:
                  r?.status === "published"
                    ? "Withdraw announcement"
                    : "Publish announcement",
                export: "Download application records",
              }[type]
            }
          </h2>
          <button aria-label="Close dialog" disabled={busy} onClick={close}>
            <X size={21} />
          </button>
        </div>
        {r?.email && <p>{r.email}</p>}
        {["user", "subscription", "ticket", "announcement"].includes(type) && (
          <form onSubmit={submit}>
            <fieldset disabled={busy}>
              {type === "user" && (
                <>
                  <p className="notice compact">
                    Suspension blocks backend access. It does not delete data,
                    revoke Firebase sign-in, or remove locally saved reminders.
                  </p>
                  <label>
                    Cloud access
                    <select name="status" defaultValue={r.status}>
                      <option value="active">Active</option>
                      <option value="suspended">Suspended</option>
                    </select>
                  </label>
                  <label>
                    Reason
                    <textarea
                      name="reason"
                      required
                      minLength={3}
                      maxLength={500}
                      defaultValue={r.reason}
                    />
                  </label>
                </>
              )}
              {type === "subscription" && (
                <>
                  <div className="notice compact">
                    This updates a manual plan record; no charge is made and no
                    payment subscription is created.
                  </div>
                  <label>
                    Plan
                    <select name="plan" defaultValue={r.plan}>
                      <option value="free">Free</option>
                      <option value="monthly">Monthly</option>
                      <option value="yearly">Yearly</option>
                    </select>
                  </label>
                  <label>
                    Expiry date (required for paid-plan labels)
                    <input
                      name="expiry"
                      type="date"
                      defaultValue={r.expires_at?.slice(0, 10) || ""}
                    />
                  </label>
                  <label>
                    Note
                    <textarea
                      name="note"
                      defaultValue={r.note||""}
                      required
                      minLength={3}
                      maxLength={500}
                    />
                  </label>
                </>
              )}
              {type === "ticket" && (
                <>
                  <h3>{r.subject}</h3>
                  <p className="preserve">{r.message}</p>
                  <label>
                    Status
                    <select name="status" defaultValue={r.status}>
                      {["open", "in_progress", "resolved"].map((s) => (
                        <option key={s} value={s}>
                          {pretty(s)}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label>
                    Reply visible to the user
                    <textarea
                      name="reply"
                      maxLength={4000}
                      defaultValue={r.reply}
                      rows={5}
                    />
                  </label>
                </>
              )}
              {type === "announcement" && (
                <>
                  <label>
                    Title
                    <input
                      name="title"
                      required
                      minLength={3}
                      maxLength={120}
                    />
                  </label>
                  <label>
                    Message
                    <textarea
                      name="body"
                      required
                      minLength={3}
                      maxLength={2000}
                      rows={6}
                    />
                  </label>
                  <small>
                    Saved as a draft first. You can review before publishing.
                  </small>
                </>
              )}
              <button className="primary" disabled={busy}>
                {busy
                  ? "Saving…"
                  : type === "announcement"
                    ? "Save draft"
                    : "Save changes"}
              </button>
            </fieldset>
          </form>
        )}
        {type === "publish" && (
          <>
            <h3>{r.title}</h3>
            <p className="preserve">{r.body}</p>
            <p>
              {r.status === "published"
                ? "This removes the announcement from the app inbox."
                : "This announcement will become visible to all signed-in app users when they open the inbox."}
            </p>
            <button
              className="primary"
              disabled={busy}
              onClick={() =>
                mutate("/announcements/" + r.id, "PATCH", {
                  status: r.status === "published" ? "withdrawn" : "published",
                  baseVersion: r.version,
                })
              }
            >
              {busy
                ? "Saving…"
                : r.status === "published"
                  ? "Withdraw"
                  : "Publish to app inbox"}
            </button>
          </>
        )}
        {type === "export" && (
          <>
            <p>
              The download contains personal user information and support
              messages. Store it privately.
            </p>
            <p>Media binaries and authentication credentials are excluded.</p>
            <button className="primary" disabled={busy} onClick={exportData}>
              {busy ? "Preparing…" : "Download JSON export"}
            </button>
          </>
        )}
      </section>
    </div>
  );
}
export { App, Dashboard, upcomingRows };
