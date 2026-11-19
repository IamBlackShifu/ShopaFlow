import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { deleteApp, initializeApp } from 'firebase/app';
import {
  createUserWithEmailAndPassword,
  deleteUser,
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
  updateProfile,
  User,
} from 'firebase/auth';
import {
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  query,
  setDoc,
  updateDoc,
  writeBatch,
  where,
} from 'firebase/firestore';
import {
  AlertTriangle,
  BarChart3,
  Boxes,
  Building2,
  CalendarDays,
  CheckCircle2,
  CircleDollarSign,
  Lock,
  LogOut,
  Plus,
  Power,
  RefreshCw,
  ReceiptText,
  Search,
  ShieldCheck,
  Store,
  Users,
  Files,
} from 'lucide-react';
import { auth, db, firebaseConfig } from './firebase';
import { DocumentsPage, type CommercialDocument } from './DocumentsPage';
import { friendlyError } from './errors';
import './styles.css';

type Role = 'owner' | 'admin' | 'manager' | 'cashier';
type Tab = 'overview' | 'sales' | 'documents' | 'stores' | 'inventory' | 'team';

type Membership = {
  companyId: string;
  userId: string;
  role: Role;
  companyName: string;
  subscriptionStatus: SubscriptionStatus;
};

type SubscriptionStatus = 'active' | 'pending';
type FirestoreDate = string | Date | { toDate: () => Date };
type CompanyRow = {
  id: string;
  name?: string;
  owner_user_id?: string;
  plan?: string;
  subscription_status?: string;
  operating_status?: string;
  suspension_reason?: string;
  created_at?: FirestoreDate;
  subscription_updated_at?: FirestoreDate;
  subscription_started_at?: FirestoreDate;
  last_payment_at?: FirestoreDate;
  next_payment_due_at?: FirestoreDate;
  billing_cycle_days?: number;
  last_payment_amount?: number;
  billing_currency?: string;
  payment_reference?: string;
  payment_count?: number;
};

type StoreRow = { id: string; company_id?: string; name?: string; address?: string; created_at?: string };
type CategoryRow = { id: string; company_id?: string; name?: string; normalized_name?: string; deleted_at?: string | null };
type ProductRow = {
  id: string;
  local_id?: string | number;
  sync_id?: string;
  company_id?: string;
  name?: string;
  category?: string;
  stock_quantity?: number;
  min_stock_level?: number;
  price?: number;
  cost?: number;
  deleted_at?: string | null;
};
type SaleRow = {
  id: string;
  local_id?: string | number;
  sync_id?: string;
  company_id?: string;
  store_id?: string;
  total_amount?: number;
  payment_method?: string;
  sale_date?: string;
  receipt_number?: string;
  deleted_at?: string | null;
};
type SaleItemRow = {
  id: string;
  sync_id?: string;
  company_id?: string;
  store_id?: string;
  sale_id?: string | number;
  sale_sync_id?: string;
  product_id?: string | number;
  product_sync_id?: string;
  quantity?: number;
  unit_price?: number;
  total_price?: number;
  deleted_at?: string | null;
};
type TeamRow = {
  id: string;
  company_id?: string;
  store_id?: string;
  name?: string;
  email?: string;
  role?: Role;
  updated_at?: string;
};
type EmployeeDraft = { name: string; email: string; password: string; role: Role; storeId: string };

const canManageCompany = (role: Role) => role === 'owner' || role === 'admin';
const canManageInventory = (role: Role) => role === 'owner' || role === 'admin' || role === 'manager';
const canCreateRole = (actor: Role, target: Role) => actor === 'owner' ? target !== 'owner' : target === 'manager' || target === 'cashier';
const roleRank: Record<Role, number> = { owner: 4, admin: 3, manager: 2, cashier: 1 };
const SUPER_ADMIN_UID = 'RAKsm1i4I3TLQA17nJulIZOx8ip2';

async function stableId(prefix: string, seed: string) {
  const encoded = new TextEncoder().encode(seed.trim().toLowerCase());
  const hash = await crypto.subtle.digest('SHA-256', encoded);
  const hex = Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${prefix}_${hex.slice(0, 20)}`;
}

function roleLabel(role: Role) {
  return role.charAt(0).toUpperCase() + role.slice(1);
}

function LoginScreen() {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [resettingPassword, setResettingPassword] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [ownerName, setOwnerName] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [storeName, setStoreName] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError('');
    setNotice('');
    try {
      if (resettingPassword) {
        await sendPasswordResetEmail(auth, email.trim().toLowerCase());
        setNotice('If an account exists for that email, a password reset link has been sent.');
      } else if (mode === 'login') {
        await signInWithEmailAndPassword(auth, email.trim().toLowerCase(), password);
      } else {
        const credential = await createUserWithEmailAndPassword(auth, email.trim().toLowerCase(), password);
        await updateProfile(credential.user, { displayName: ownerName.trim() });
        const companyId = await stableId('cmp', credential.user.uid);
        const storeId = await stableId('store', companyId);
        const registerId = `${storeId}_register`;
        const now = new Date().toISOString();
        const cleanCompanyName = companyName.trim();
        const cleanStoreName = storeName.trim() || cleanCompanyName;
        const batch = writeBatch(db);
        batch.set(doc(db, 'companies', companyId), {
            id: companyId,
            name: cleanCompanyName,
            owner_user_id: credential.user.uid,
            plan: 'starter',
            subscription_status: 'pending',
            operating_status: 'paused',
            suspension_reason: 'Awaiting subscription activation',
            created_at: now,
            updated_at: now,
            sync_status: 'pending',
          });
        batch.set(doc(db, 'companies', companyId, 'stores', storeId), {
            id: storeId,
            company_id: companyId,
            name: cleanStoreName,
            created_at: now,
            updated_at: now,
            sync_status: 'pending',
          });
        batch.set(doc(db, 'companies', companyId, 'users', credential.user.uid), {
            id: credential.user.uid,
            company_id: companyId,
            store_id: storeId,
            register_id: registerId,
            name: ownerName.trim(),
            email: credential.user.email,
            role: 'owner',
            created_at: now,
            updated_at: now,
            sync_status: 'pending',
          });
        batch.set(doc(db, 'user_memberships', credential.user.uid, 'companies', companyId), {
            company_id: companyId,
            company_name: cleanCompanyName,
            user_id: credential.user.uid,
            store_id: storeId,
            register_id: registerId,
            email: credential.user.email,
            role: 'owner',
            updated_at: new Date(),
          });
        await batch.commit();
      }
    } catch (err) {
      const code = typeof err === 'object' && err && 'code' in err ? String(err.code) : '';
      if (resettingPassword && code === 'auth/user-not-found') {
        setNotice('If an account exists for that email, a password reset link has been sent.');
      } else {
        setError(friendlyError(err, resettingPassword ? 'We could not send the reset email. Please try again.' : mode === 'login' ? 'Unable to sign in. Please try again.' : 'Unable to create the account. Please try again.'));
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="auth-shell">
      <form className="auth-panel" onSubmit={submit}>
        <div className="brand-row">
          <div className="brand-mark">SF</div>
          <div>
            <strong>ShopaFlow</strong>
            <span>Admin Console</span>
          </div>
        </div>
        <div>
          <h1>{resettingPassword ? 'Reset your password' : mode === 'login' ? 'Welcome back' : 'Create company workspace'}</h1>
          <p>{resettingPassword ? 'Enter your account email and we will send you a secure reset link.' : mode === 'login' ? 'Manage stores, stock, and staff with company-scoped access.' : 'This creates the first owner account for a company.'}</p>
        </div>
        {!resettingPassword && <div className="segmented">
          <button type="button" className={mode === 'login' ? 'active' : ''} onClick={() => { setMode('login'); setError(''); setNotice(''); }}>Sign in</button>
          <button type="button" className={mode === 'register' ? 'active' : ''} onClick={() => { setMode('register'); setError(''); setNotice(''); }}>Register</button>
        </div>}
        {!resettingPassword && mode === 'register' && (
          <div className="field-grid">
            <label>Company name<input value={companyName} onChange={(event) => setCompanyName(event.target.value)} required /></label>
            <label>Owner name<input value={ownerName} onChange={(event) => setOwnerName(event.target.value)} required /></label>
            <label>Main store name<input value={storeName} onChange={(event) => setStoreName(event.target.value)} placeholder="Defaults to company name" /></label>
          </div>
        )}
        <label>Email<input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required /></label>
        {!resettingPassword && <label>Password<input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required minLength={6} /></label>}
        {!resettingPassword && mode === 'login' && <button className="text-button forgot-link" type="button" onClick={() => { setResettingPassword(true); setError(''); setNotice(''); }}>Forgot password?</button>}
        {error && <div className="banner error"><AlertTriangle size={16} />{error}</div>}
        {notice && <div className="banner notice"><CheckCircle2 size={16} />{notice}</div>}
        <button className="primary" disabled={busy}>{busy ? 'Working...' : resettingPassword ? 'Send reset link' : mode === 'login' ? 'Sign in' : 'Create owner account'}</button>
        {resettingPassword && <button className="text-button" type="button" onClick={() => { setResettingPassword(false); setError(''); setNotice(''); }}>Back to sign in</button>}
      </form>
    </main>
  );
}

function useMembership(user: User | null) {
  const [membership, setMembership] = useState<Membership | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    let unsubscribeCompany = () => {};
    async function load() {
      if (!user) {
        setMembership(null);
        setLoading(false);
        return;
      }

      setLoading(true);
      const memberships = await getDocs(query(collection(db, 'user_memberships', user.uid, 'companies'), limit(1)));
      let companyId = memberships.docs[0]?.id ?? '';
      let data = memberships.docs[0]?.data() as { role?: Role; company_name?: string; company_id?: string; store_id?: string; register_id?: string; email?: string } | undefined;

      if (!companyId) {
        const companyUsers = await getDocs(query(collectionGroup(db, 'users'), where('id', '==', user.uid), limit(1)));
        const userDoc = companyUsers.docs[0];
        companyId = userDoc?.ref.parent.parent?.id ?? '';
        data = userDoc?.data() as typeof data;
        if (companyId && data) {
          await setDoc(doc(db, 'user_memberships', user.uid, 'companies', companyId), {
            company_id: companyId,
            company_name: data.company_name || companyId,
            user_id: user.uid,
            store_id: data.store_id,
            register_id: data.register_id,
            email: data.email || user.email,
            role: data.role || 'cashier',
            updated_at: new Date(),
          }, { merge: true });
        }
      }

      if (!active) return;
      if (!companyId || !data) {
        setMembership(null);
        setLoading(false);
        return;
      }
      const company = await getDoc(doc(db, 'companies', companyId));
      const companyData = company.data() as CompanyRow | undefined;
      setMembership({
        companyId,
        userId: user.uid,
        role: (data.role ?? 'cashier') as Role,
        companyName: companyData?.name || data.company_name || companyId,
        subscriptionStatus: companyData?.subscription_status === 'active' && companyData?.operating_status === 'active' ? 'active' : 'pending',
      });
      unsubscribeCompany = onSnapshot(doc(db, 'companies', companyId), (snapshot) => {
        if (!active) return;
        const nextCompany = snapshot.data() as CompanyRow | undefined;
        setMembership((current) => current ? {
          ...current,
          companyName: nextCompany?.name || current.companyName,
          subscriptionStatus: nextCompany?.subscription_status === 'active' && nextCompany?.operating_status === 'active' ? 'active' : 'pending',
        } : current);
      });
      setLoading(false);
    }
    load().catch(() => {
      if (active) setLoading(false);
    });
    return () => {
      active = false;
      unsubscribeCompany();
    };
  }, [user]);

  return { membership, loading };
}

function AdminApp({ user }: { user: User }) {
  const { membership, loading } = useMembership(user);
  const [tab, setTab] = useState<Tab>('overview');
  const [stores, setStores] = useState<StoreRow[]>([]);
  const [products, setProducts] = useState<ProductRow[]>([]);
  const [categories, setCategories] = useState<CategoryRow[]>([]);
  const [sales, setSales] = useState<SaleRow[]>([]);
  const [saleItems, setSaleItems] = useState<SaleItemRow[]>([]);
  const [team, setTeam] = useState<TeamRow[]>([]);
  const [documents, setDocuments] = useState<CommercialDocument[]>([]);
  const [queryText, setQueryText] = useState('');
  const [loadingData, setLoadingData] = useState(false);
  const [dataError, setDataError] = useState('');

  async function loadWorkspace(nextMembership = membership) {
    if (!nextMembership || nextMembership.subscriptionStatus !== 'active') return;
    setLoadingData(true);
    setDataError('');
    try {
      const base = doc(db, 'companies', nextMembership.companyId);
      const [storeDocs, productDocs, categoryDocs, saleDocs, saleItemDocs, teamDocs, documentDocs] = await Promise.all([
        getDocs(collection(base, 'stores')),
        getDocs(collection(base, 'products')),
        getDocs(collection(base, 'categories')).catch(() => null),
        getDocs(collection(base, 'sales')),
        getDocs(collection(base, 'sale_items')),
        getDocs(collection(base, 'users')),
        getDocs(collection(base, 'documents')).catch(() => null),
      ]);
      const onlyCompany = <T extends { company_id?: string }>(row: T) => !row.company_id || row.company_id === nextMembership.companyId;
      setStores(storeDocs.docs.map((item) => ({ ...item.data(), id: item.id } as StoreRow)).filter(onlyCompany).sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      setProducts(productDocs.docs.map((item) => {
        const data = item.data() as ProductRow;
        return { ...data, local_id: data.id, id: item.id };
      }).filter(onlyCompany).filter((item) => !item.deleted_at).sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      setCategories((categoryDocs?.docs ?? []).map((item) => ({ ...item.data(), id: item.id } as CategoryRow)).filter(onlyCompany).filter((item) => !item.deleted_at).sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      setSales(saleDocs.docs.map((item) => {
        const data = item.data() as SaleRow;
        return { ...data, local_id: data.id, id: item.id };
      }).filter(onlyCompany).filter((item) => !item.deleted_at));
      setSaleItems(saleItemDocs.docs.map((item) => ({ ...item.data(), id: item.id } as SaleItemRow)).filter(onlyCompany).filter((item) => !item.deleted_at));
      setTeam(teamDocs.docs.map((item) => ({ ...item.data(), id: item.id } as TeamRow)).filter((item) => item.company_id === nextMembership.companyId).sort((a, b) => roleRank[b.role || 'cashier'] - roleRank[a.role || 'cashier'] || (a.name || '').localeCompare(b.name || '')));
      setDocuments((documentDocs?.docs ?? []).map((item) => ({ ...item.data(), id: item.id } as CommercialDocument)).filter(onlyCompany).sort((a, b) => (b.updated_at || '').localeCompare(a.updated_at || '')));
    } catch (error) {
      setDataError(friendlyError(error, 'Unable to load dashboard data. Please try again.'));
    } finally {
      setLoadingData(false);
    }
  }

  useEffect(() => {
    loadWorkspace();
  }, [membership?.companyId]);

  const lowStock = useMemo(() => products.filter((item) => Number(item.stock_quantity ?? 0) <= Number(item.min_stock_level ?? 5)), [products]);
  const inventoryValue = useMemo(() => products.reduce((sum, item) => sum + Number(item.stock_quantity ?? 0) * Number(item.price ?? 0), 0), [products]);
  const filteredProducts = useMemo(() => products.filter((item) => `${item.name ?? ''} ${item.category ?? ''}`.toLowerCase().includes(queryText.toLowerCase())), [products, queryText]);

  if (loading) return <div className="center">Loading workspace...</div>;
  if (!membership) return <NoMembershipView user={user} />;
  if (membership.subscriptionStatus !== 'active') return <SubscriptionPendingView companyName={membership.companyName} user={user} />;
  if (membership.role === 'cashier') return <div className="center"><Lock size={24} /> Cashiers use the POS app. Admin dashboard access requires manager or higher.</div>;

  const nav = [
    ['overview', BarChart3, 'Overview'],
    ['sales', ReceiptText, 'Sales'],
    ['documents', Files, 'Invoices & quotes'],
    ['stores', Store, 'Stores'],
    ['inventory', Boxes, 'Inventory'],
    ...(canManageCompany(membership.role) ? [['team', Users, 'Team'] as const] : []),
  ] as const;

  return (
    <div className="app-shell">
      <aside>
        <div className="aside-brand"><Building2 /> <span>ShopaFlow</span></div>
        <nav>
          {nav.map(([id, Icon, label]) => (
            <button key={id} className={tab === id ? 'active' : ''} onClick={() => setTab(id as Tab)}>
              <Icon size={18} /> {label}
            </button>
          ))}
        </nav>
        <div className="aside-user">
          <span>{user.email}</span>
          <strong>{roleLabel(membership.role)}</strong>
        </div>
        <button className="ghost" onClick={() => signOut(auth)}><LogOut size={18} /> Sign out</button>
      </aside>
      <main>
        <header>
          <div>
            <p className="eyebrow">Company workspace</p>
            <h1>{membership.companyName}</h1>
            <p><ShieldCheck size={16} /> {roleLabel(membership.role)} access</p>
          </div>
          <button className="secondary" onClick={() => loadWorkspace()} disabled={loadingData}>
            <RefreshCw size={16} /> {loadingData ? 'Refreshing...' : 'Refresh'}
          </button>
        </header>
        {dataError && <div className="banner error"><AlertTriangle size={16} />{dataError}</div>}
        {tab === 'overview' && <Overview stores={stores} products={products} lowStock={lowStock} team={team} inventoryValue={inventoryValue} />}
        {tab === 'sales' && <SalesPage stores={stores} products={products} sales={sales} saleItems={saleItems} />}
        {tab === 'documents' && <DocumentsPage companyId={membership.companyId} companyName={membership.companyName} userId={user.uid} canManageSettings={canManageCompany(membership.role)} stores={stores} products={products} documents={documents} onChanged={() => loadWorkspace()} />}
        {tab === 'stores' && <Stores companyId={membership.companyId} stores={stores} canEdit={canManageCompany(membership.role)} onChanged={() => loadWorkspace()} />}
        {tab === 'inventory' && <Inventory companyId={membership.companyId} stores={stores} products={filteredProducts} categories={categories} canEdit={canManageInventory(membership.role)} queryText={queryText} onQuery={setQueryText} onChanged={() => loadWorkspace()} />}
        {tab === 'team' && <Team companyId={membership.companyId} companyName={membership.companyName} actorRole={membership.role} stores={stores} team={team} canEdit={canManageCompany(membership.role)} onChanged={() => loadWorkspace()} />}
      </main>
    </div>
  );
}

function SubscriptionPendingView({ companyName, user }: { companyName: string; user: User }) {
  return (
    <main className="subscription-shell">
      <section className="subscription-card">
        <div className="subscription-icon"><CircleDollarSign size={34} /></div>
        <p className="eyebrow">Subscription required</p>
        <h1>{companyName} is currently paused</h1>
        <p>Your workspace and point-of-sale data remain safely stored. Complete your subscription payment, then ask the ShopaFlow team to activate your shop.</p>
        <div className="subscription-status"><span /><div><strong>Payment pending</strong><small>Access resumes immediately after activation.</small></div></div>
        <div className="subscription-actions">
          <a className="primary" href="mailto:support@shopaflow.app?subject=Activate%20my%20ShopaFlow%20subscription">Contact ShopaFlow</a>
          <button className="secondary" onClick={() => window.location.reload()}><RefreshCw size={16} /> Check again</button>
        </div>
        <button className="text-button" onClick={() => signOut(auth)}><LogOut size={16} /> Sign out of {user.email}</button>
      </section>
    </main>
  );
}

function NoMembershipView({ user }: { user: User }) {
  return (
    <main className="access-state-shell">
      <section className="access-state-card">
        <div className="access-state-icon"><Lock size={30} /></div>
        <p className="eyebrow">Account not linked</p>
        <h1>No company membership found</h1>
        <p>This browser is signed in as <strong>{user.email || user.uid}</strong>, but that account is not linked to a company or the platform administration team.</p>
        <div className="signed-identity"><span>Current Firebase UID</span><code>{user.uid}</code></div>
        <button className="primary" onClick={() => signOut(auth)}><LogOut size={17} /> Switch account</button>
      </section>
    </main>
  );
}

const BILLING_CYCLE_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

function asDate(value?: FirestoreDate) {
  if (!value) return null;
  const parsed = value instanceof Date ? value : typeof value === 'object' && 'toDate' in value ? value.toDate() : new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function formatShortDate(value?: FirestoreDate | null) {
  const date = value ? asDate(value) : null;
  return date ? date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) : 'Not scheduled';
}

function billingAnchor(company: CompanyRow) {
  return asDate(company.subscription_started_at) || asDate(company.created_at);
}

function paymentDueDate(company: CompanyRow) {
  const storedDue = asDate(company.next_payment_due_at);
  if (storedDue) return storedDue;
  const anchor = billingAnchor(company);
  return anchor ? new Date(anchor.getTime() + BILLING_CYCLE_DAYS * DAY_MS) : null;
}

function nextAnniversary(anchor: Date, from: Date) {
  const elapsed = Math.max(0, from.getTime() - anchor.getTime());
  const completedCycles = Math.floor(elapsed / (BILLING_CYCLE_DAYS * DAY_MS));
  return new Date(anchor.getTime() + (completedCycles + 1) * BILLING_CYCLE_DAYS * DAY_MS);
}

function dueState(company: CompanyRow, now = new Date()) {
  const due = paymentDueDate(company);
  if (!due) return { due: null, days: null, tone: 'unscheduled' as const, label: 'Not scheduled' };
  const days = Math.ceil((due.getTime() - now.getTime()) / DAY_MS);
  if (days < 0) return { due, days, tone: 'overdue' as const, label: `${Math.abs(days)} day${Math.abs(days) === 1 ? '' : 's'} overdue` };
  if (days === 0) return { due, days, tone: 'due-soon' as const, label: 'Due today' };
  if (days <= 7) return { due, days, tone: 'due-soon' as const, label: `Due in ${days} day${days === 1 ? '' : 's'}` };
  return { due, days, tone: 'upcoming' as const, label: `Due in ${days} days` };
}

function SuperAdminApp({ user }: { user: User }) {
  const [companies, setCompanies] = useState<CompanyRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState('');
  const [error, setError] = useState('');
  const [queryText, setQueryText] = useState('');
  const [filter, setFilter] = useState<'all' | SubscriptionStatus>('all');
  const [view, setView] = useState<'shops' | 'calendar'>('shops');
  const [paymentCompany, setPaymentCompany] = useState<CompanyRow | null>(null);
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentCurrency, setPaymentCurrency] = useState('USD');
  const [paymentReference, setPaymentReference] = useState('');

  async function loadCompanies() {
    setLoading(true);
    setError('');
    try {
      const snapshot = await getDocs(collection(db, 'companies'));
      setCompanies(snapshot.docs.map((item) => ({ ...item.data(), id: item.id } as CompanyRow)).sort((a, b) => (a.name || a.id).localeCompare(b.name || b.id)));
    } catch (err) {
      setError(friendlyError(err, 'Unable to load shops.'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { loadCompanies(); }, []);

  const statusOf = (company: CompanyRow): SubscriptionStatus => company.subscription_status === 'active' && company.operating_status === 'active' ? 'active' : 'pending';
  const activeCount = companies.filter((company) => statusOf(company) === 'active').length;
  const billingRows = companies.map((company) => ({ company, ...dueState(company) })).sort((a, b) => (a.due?.getTime() ?? Number.MAX_SAFE_INTEGER) - (b.due?.getTime() ?? Number.MAX_SAFE_INTEGER));
  const overdueCount = billingRows.filter((row) => row.tone === 'overdue').length;
  const dueSoonCount = billingRows.filter((row) => row.tone === 'due-soon').length;
  const visible = companies.filter((company) => {
    const status = statusOf(company);
    const matchesFilter = filter === 'all' || filter === status;
    const haystack = `${company.name || ''} ${company.id} ${company.plan || ''}`.toLowerCase();
    return matchesFilter && haystack.includes(queryText.trim().toLowerCase());
  });

  async function setCompanyAccess(company: CompanyRow, active: boolean) {
    setBusyId(company.id);
    setError('');
    try {
      await updateDoc(doc(db, 'companies', company.id), {
        subscription_status: active ? 'active' : 'pending',
        operating_status: active ? 'active' : 'paused',
        suspension_reason: active ? '' : 'Subscription payment pending',
        subscription_updated_at: new Date().toISOString(),
        subscription_updated_by: user.uid,
      });
      setCompanies((current) => current.map((item) => item.id === company.id ? {
        ...item,
        subscription_status: active ? 'active' : 'pending',
        operating_status: active ? 'active' : 'paused',
        suspension_reason: active ? '' : 'Subscription payment pending',
        subscription_updated_at: new Date().toISOString(),
      } : item));
    } catch (err) {
      setError(friendlyError(err, 'Unable to change this shop subscription.'));
    } finally {
      setBusyId('');
    }
  }

  function openPayment(company: CompanyRow) {
    setPaymentCompany(company);
    setPaymentAmount(company.last_payment_amount ? String(company.last_payment_amount) : '');
    setPaymentCurrency(company.billing_currency || 'USD');
    setPaymentReference('');
  }

  async function recordPayment(event: React.FormEvent) {
    event.preventDefault();
    if (!paymentCompany) return;
    const amount = Number(paymentAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      setError('Enter a payment amount greater than zero.');
      return;
    }
    const now = new Date();
    const anchor = billingAnchor(paymentCompany) || now;
    const nextDue = nextAnniversary(anchor, now);
    const changes = {
      subscription_status: 'active', operating_status: 'active', suspension_reason: '',
      subscription_started_at: anchor.toISOString(), billing_cycle_days: BILLING_CYCLE_DAYS,
      last_payment_at: now.toISOString(), next_payment_due_at: nextDue.toISOString(),
      last_payment_amount: amount, billing_currency: paymentCurrency,
      payment_reference: paymentReference.trim(), payment_count: Number(paymentCompany.payment_count || 0) + 1,
      subscription_updated_at: now.toISOString(), subscription_updated_by: user.uid,
    };
    setBusyId(paymentCompany.id);
    setError('');
    try {
      await updateDoc(doc(db, 'companies', paymentCompany.id), changes);
      setCompanies((current) => current.map((company) => company.id === paymentCompany.id ? { ...company, ...changes } : company));
      setPaymentCompany(null);
      setPaymentAmount('');
      setPaymentReference('');
    } catch (err) {
      setError(friendlyError(err, 'Unable to record this payment.'));
    } finally {
      setBusyId('');
    }
  }

  return (
    <div className="super-shell">
      <aside className="super-aside">
        <div className="aside-brand"><ShieldCheck /> <span>ShopaFlow</span></div>
        <nav className="super-nav">
          <button className={view === 'shops' ? 'active' : ''} onClick={() => setView('shops')}><Building2 size={18} /> Shop access</button>
          <button className={view === 'calendar' ? 'active' : ''} onClick={() => setView('calendar')}><CalendarDays size={18} /> Payment calendar</button>
        </nav>
        <div className="aside-user"><span>{user.email}</span><strong>Super admin</strong></div>
        <button className="ghost" onClick={() => signOut(auth)}><LogOut size={18} /> Sign out</button>
      </aside>
      <main className="super-main">
        <header className="super-header">
          <div><p className="eyebrow">Platform control centre</p><h1>{view === 'shops' ? 'Subscription access' : 'Payment calendar'}</h1><p>{view === 'shops' ? 'Activate paid shops or pause access when a subscription is outstanding.' : 'A lightweight 30-day payment schedule anchored to each shop signup date.'}</p></div>
          <button className="secondary" onClick={loadCompanies} disabled={loading}><RefreshCw size={16} /> {loading ? 'Refreshing...' : 'Refresh'}</button>
        </header>
        {error && <div className="banner error"><AlertTriangle size={16} />{error}</div>}
        <section className="super-metrics">
          <div><span>Total shops</span><strong>{companies.length}</strong><small>Registered workspaces</small></div>
          <div className="success"><span>Operating</span><strong>{activeCount}</strong><small>Subscription active</small></div>
          <div className="warning"><span>Due within 7 days</span><strong>{dueSoonCount}</strong><small>Including payments due today</small></div>
          <div className="danger"><span>Overdue</span><strong>{overdueCount}</strong><small>Needs subscription follow-up</small></div>
        </section>
        {view === 'shops' && <section className="shop-directory">
          <div className="directory-head"><div><h2>Shop directory</h2><p>Changes take effect in the POS and back office immediately.</p></div><div className="directory-tools"><label className="search-box"><Search size={16} /><input value={queryText} onChange={(event) => setQueryText(event.target.value)} placeholder="Search shops" /></label><select value={filter} onChange={(event) => setFilter(event.target.value as typeof filter)}><option value="all">All statuses</option><option value="active">Active</option><option value="pending">Payment pending</option></select></div></div>
          <div className="shop-list">
            {visible.map((company) => {
              const status = statusOf(company);
              const activating = busyId === company.id;
              const schedule = dueState(company);
              return <article className="shop-row" key={company.id}>
                <div className="shop-avatar">{(company.name || 'S').slice(0, 2).toUpperCase()}</div>
                <div className="shop-identity"><strong>{company.name || 'Unnamed shop'}</strong><span>{company.id}</span><small>Plan: {company.plan || 'Starter'} · Joined {formatShortDate(company.created_at)}</small></div>
                <small className={`due-label ${schedule.tone}`}>Next payment: {formatShortDate(schedule.due)} · {schedule.label}</small>
                <span className={`subscription-badge ${status}`}><i />{status === 'active' ? 'Operating' : 'Payment pending'}</span>
                <div className="shop-actions"><button className="record-button" disabled={activating} onClick={() => openPayment(company)}><CircleDollarSign size={16} /> Record payment</button><button className={status === 'active' ? 'pause-button' : 'activate-button'} disabled={activating} onClick={() => setCompanyAccess(company, status !== 'active')}><Power size={16} />{activating ? 'Updating...' : status === 'active' ? 'Pause shop' : 'Activate shop'}</button></div>
              </article>;
            })}
            {!loading && visible.length === 0 && <div className="empty">No shops match this view.</div>}
            {loading && <div className="empty">Loading registered shops...</div>}
          </div>
        </section>}
        {view === 'calendar' && <section className="billing-calendar">
          <div className="directory-head"><div><h2>Upcoming payment anniversaries</h2><p>No background jobs required. Dates are calculated from signup and stored after each payment.</p></div><span className="cycle-pill"><CalendarDays size={15} /> Every {BILLING_CYCLE_DAYS} days</span></div>
          <div className="calendar-list">
            {billingRows.map(({ company, due, tone, label }) => <article className="calendar-row" key={company.id}>
              <div className={`calendar-date ${tone}`}><strong>{due ? due.toLocaleDateString(undefined, { day: '2-digit' }) : '—'}</strong><span>{due ? due.toLocaleDateString(undefined, { month: 'short' }) : 'No date'}</span></div>
              <div className="calendar-company"><strong>{company.name || 'Unnamed shop'}</strong><span>{company.plan || 'Starter'} plan · {statusOf(company) === 'active' ? 'Operating' : 'Paused'}</span></div>
              <div className={`due-status ${tone}`}><strong>{label}</strong><span>{due ? formatShortDate(due) : 'Starts when the first payment is recorded'}</span></div>
              <button className="record-button" disabled={busyId === company.id} onClick={() => openPayment(company)}><CircleDollarSign size={16} /> Record payment</button>
            </article>)}
            {!loading && billingRows.length === 0 && <div className="empty">No shops have been registered yet.</div>}
            {loading && <div className="empty">Loading payment schedule...</div>}
          </div>
        </section>}
      </main>
      {paymentCompany && <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setPaymentCompany(null); }}>
        <form className="payment-dialog" onSubmit={recordPayment}>
          <div><p className="eyebrow">Subscription payment</p><h2>Record payment</h2><p>Activates <strong>{paymentCompany.name || 'this shop'}</strong> and advances its fixed 30-day anniversary.</p></div>
          <div className="payment-fields"><label>Amount<input type="number" min="0.01" step="0.01" value={paymentAmount} onChange={(event) => setPaymentAmount(event.target.value)} autoFocus required /></label><label>Currency<select value={paymentCurrency} onChange={(event) => setPaymentCurrency(event.target.value)}><option value="USD">USD</option><option value="ZWG">ZWG</option><option value="ZAR">ZAR</option></select></label></div>
          <label>Reference (optional)<input value={paymentReference} onChange={(event) => setPaymentReference(event.target.value)} placeholder="Receipt or transfer reference" /></label>
          <div className="payment-preview"><CalendarDays size={18} /><span>Next due date<strong>{formatShortDate(nextAnniversary(billingAnchor(paymentCompany) || new Date(), new Date()))}</strong></span></div>
          <div className="dialog-actions"><button type="button" className="secondary" onClick={() => setPaymentCompany(null)}>Cancel</button><button className="primary" disabled={busyId === paymentCompany.id}><CircleDollarSign size={16} /> {busyId === paymentCompany.id ? 'Saving...' : 'Save payment & activate'}</button></div>
        </form>
      </div>}
    </div>
  );
}

function Overview({ stores, products, lowStock, team, inventoryValue }: { stores: StoreRow[]; products: ProductRow[]; lowStock: ProductRow[]; team: TeamRow[]; inventoryValue: number }) {
  return (
    <div className="page-stack">
      <section className="metrics-grid">
        <Metric label="Stores" value={stores.length} detail="Active locations" />
        <Metric label="Products" value={products.length} detail="Company catalogue" />
        <Metric label="Low stock" value={lowStock.length} detail="Needs attention" tone={lowStock.length ? 'warn' : 'ok'} />
        <Metric label="Team" value={team.length} detail="Company users" />
      </section>
      <section>
        <div className="section-head">
          <div>
            <h2>Operational Snapshot</h2>
            <p>Quick health check across stores and inventory.</p>
          </div>
        </div>
        <div className="insight-grid">
          <div><span>Inventory value</span><strong>${inventoryValue.toFixed(2)}</strong></div>
          <div><span>Stock coverage</span><strong>{products.length - lowStock.length}/{products.length}</strong></div>
          <div><span>RBAC state</span><strong>Company scoped</strong></div>
        </div>
      </section>
      <section>
        <div className="section-head">
          <div>
            <h2>Low Stock Watchlist</h2>
            <p>Products at or below their minimum stock level.</p>
          </div>
        </div>
        <DataTable
          empty="No low stock products."
          columns={['Product', 'Category', 'Stock', 'Min']}
          rows={lowStock.slice(0, 8).map((item) => [item.name || item.id, item.category || 'Uncategorised', String(item.stock_quantity ?? 0), String(item.min_stock_level ?? 5)])}
        />
      </section>
    </div>
  );
}

function Metric({ label, value, detail, tone }: { label: string; value: number | string; detail: string; tone?: 'warn' | 'ok' }) {
  return (
    <div className={`metric ${tone ?? ''}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </div>
  );
}

function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function parseSaleDate(value?: string) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function saleDateKey(value?: string) {
  if (value && /^\d{4}-\d{2}-\d{2}/.test(value)) return value.slice(0, 10);
  return parseSaleDate(value)?.toISOString().slice(0, 10) ?? '';
}

function money(value: number) {
  return `$${value.toFixed(2)}`;
}

function SalesPage({ stores, products, sales, saleItems }: { stores: StoreRow[]; products: ProductRow[]; sales: SaleRow[]; saleItems: SaleItemRow[] }) {
  const [startDate, setStartDate] = useState(todayIsoDate());
  const [endDate, setEndDate] = useState(todayIsoDate());
  const [storeId, setStoreId] = useState('all');
  const [paymentMethod, setPaymentMethod] = useState('all');
  const [searchText, setSearchText] = useState('');

  const productLookup = useMemo(() => {
    const lookup = new Map<string, ProductRow>();
    for (const product of products) {
      lookup.set(product.id, product);
      if (product.sync_id) lookup.set(product.sync_id, product);
      if (product.local_id !== undefined) lookup.set(String(product.local_id), product);
    }
    return lookup;
  }, [products]);

  const filteredSales = useMemo(() => {
    return sales
      .filter((sale) => {
        const key = saleDateKey(sale.sale_date);
        if (!key) return false;
        if (startDate && key < startDate) return false;
        if (endDate && key > endDate) return false;
        if (storeId !== 'all' && sale.store_id !== storeId) return false;
        if (paymentMethod !== 'all' && (sale.payment_method || '').toLowerCase() !== paymentMethod) return false;
        return true;
      })
      .sort((a, b) => (parseSaleDate(b.sale_date)?.getTime() ?? 0) - (parseSaleDate(a.sale_date)?.getTime() ?? 0));
  }, [sales, startDate, endDate, storeId, paymentMethod]);

  const filteredSaleIds = useMemo(() => new Set(filteredSales.flatMap((sale) => [sale.id, sale.sync_id, sale.local_id?.toString()].filter(Boolean) as string[])), [filteredSales]);

  const soldItems = useMemo(() => {
    const rows = saleItems
      .filter((item) => filteredSaleIds.has(String(item.sale_sync_id || item.sale_id || '')))
      .map((item) => {
        const product = productLookup.get(String(item.product_sync_id || item.product_id || ''));
        const quantity = Number(item.quantity ?? 0);
        const unitPrice = Number(item.unit_price ?? product?.price ?? 0);
        const cost = Number(product?.cost ?? 0);
        const revenue = Number(item.total_price ?? unitPrice * quantity);
        const profit = (unitPrice - cost) * quantity;
        return {
          id: item.id,
          productName: product?.name || String(item.product_id || item.product_sync_id || 'Unknown product'),
          category: product?.category || 'Uncategorised',
          quantity,
          unitPrice,
          cost,
          revenue,
          profit,
        };
      })
      .filter((item) => `${item.productName} ${item.category}`.toLowerCase().includes(searchText.toLowerCase()));

    const grouped = new Map<string, typeof rows[number]>();
    for (const row of rows) {
      const current = grouped.get(row.productName) || { ...row, quantity: 0, revenue: 0, profit: 0 };
      current.quantity += row.quantity;
      current.revenue += row.revenue;
      current.profit += row.profit;
      grouped.set(row.productName, current);
    }
    return Array.from(grouped.values()).sort((a, b) => b.revenue - a.revenue);
  }, [saleItems, filteredSaleIds, productLookup, searchText]);

  const paymentMethods = useMemo(() => {
    return Array.from(new Set(sales.map((sale) => (sale.payment_method || '').toLowerCase()).filter(Boolean))).sort();
  }, [sales]);

  const totals = useMemo(() => {
    const revenue = soldItems.reduce((sum, item) => sum + item.revenue, 0);
    const profit = soldItems.reduce((sum, item) => sum + item.profit, 0);
    const quantity = soldItems.reduce((sum, item) => sum + item.quantity, 0);
    return { revenue, profit, quantity };
  }, [soldItems]);

  return (
    <div className="page-stack">
      <section>
        <div className="section-head">
          <div>
            <h2>Sales</h2>
            <p>Review what sold during the selected period. Profit is tentative and uses product cost at the time of viewing.</p>
          </div>
        </div>
        <div className="filter-grid">
          <label>From<input type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} /></label>
          <label>To<input type="date" value={endDate} onChange={(event) => setEndDate(event.target.value)} /></label>
          <label>
            Store
            <select value={storeId} onChange={(event) => setStoreId(event.target.value)}>
              <option value="all">All stores</option>
              {stores.map((store) => <option key={store.id} value={store.id}>{store.name || store.id}</option>)}
            </select>
          </label>
          <label>
            Payment
            <select value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value)}>
              <option value="all">All methods</option>
              {paymentMethods.map((method) => <option key={method} value={method}>{method}</option>)}
            </select>
          </label>
          <label>Product search<input value={searchText} onChange={(event) => setSearchText(event.target.value)} placeholder="Name or category" /></label>
        </div>
      </section>

      <section className="metrics-grid">
        <Metric label="Revenue" value={money(totals.revenue)} detail={`${filteredSales.length} transactions`} />
        <Metric label="Profit" value={money(totals.profit)} detail="Tentative gross profit" tone={totals.profit >= 0 ? 'ok' : 'warn'} />
        <Metric label="Quantity sold" value={totals.quantity.toFixed(3).replace(/\.?0+$/, '')} detail="Units or kg sold" />
        <Metric label="Products sold" value={soldItems.length} detail="Unique products" />
      </section>

      <section>
        <div className="section-head">
          <div>
            <h2>Items Sold</h2>
            <p>Grouped by product for the selected filters.</p>
          </div>
        </div>
        <DataTable
          empty="No sold items found for this filter."
          columns={['Product', 'Category', 'Qty', 'Revenue', 'Unit cost', 'Profit']}
          rows={soldItems.map((item) => [
            item.productName,
            item.category,
            item.quantity.toFixed(3).replace(/\.?0+$/, ''),
            money(item.revenue),
            money(item.cost),
            money(item.profit),
          ])}
        />
      </section>

      <section>
        <div className="section-head">
          <div>
            <h2>Transactions</h2>
            <p>Receipts included in the selected period.</p>
          </div>
        </div>
        <DataTable
          empty="No transactions found for this filter."
          columns={['Receipt', 'Date', 'Store', 'Payment', 'Total']}
          rows={filteredSales.map((sale) => [
            sale.receipt_number || sale.id,
            parseSaleDate(sale.sale_date)?.toLocaleString() || '',
            stores.find((store) => store.id === sale.store_id)?.name || sale.store_id || '',
            sale.payment_method || '',
            money(Number(sale.total_amount ?? 0)),
          ])}
        />
      </section>
    </div>
  );
}

function Stores({ companyId, stores, canEdit, onChanged }: { companyId: string; stores: StoreRow[]; canEdit: boolean; onChanged: () => void }) {
  const [name, setName] = useState('');
  const [address, setAddress] = useState('');

  async function addStore(event: React.FormEvent) {
    event.preventDefault();
    if (!canEdit || !name.trim()) return;
    const id = `store_${crypto.randomUUID()}`;
    await setDoc(doc(db, 'companies', companyId, 'stores', id), {
      id,
      company_id: companyId,
      name: name.trim(),
      address: address.trim(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      sync_status: 'pending',
    });
    setName('');
    setAddress('');
    onChanged();
  }

  return (
    <section>
      <div className="section-head">
        <div>
          <h2>Stores</h2>
          <p>Locations are scoped to this company only.</p>
        </div>
        {!canEdit && <span className="pill"><Lock size={14} /> read only</span>}
      </div>
      {canEdit && (
        <form className="inline-form" onSubmit={addStore}>
          <input value={name} onChange={(event) => setName(event.target.value)} placeholder="Store name" />
          <input value={address} onChange={(event) => setAddress(event.target.value)} placeholder="Address" />
          <button className="primary"><Plus size={16} /> Add store</button>
        </form>
      )}
      <DataTable empty="No stores yet." columns={['Name', 'Address']} rows={stores.map((store) => [store.name || store.id, store.address || ''])} />
    </section>
  );
}

function Inventory({ companyId, stores, products, categories, canEdit, queryText, onQuery, onChanged }: { companyId: string; stores: StoreRow[]; products: ProductRow[]; categories: CategoryRow[]; canEdit: boolean; queryText: string; onQuery: (value: string) => void; onChanged: () => void }) {
  const [showForm, setShowForm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [draft, setDraft] = useState({ name: '', category: '', newCategory: '', storeId: stores[0]?.id || '', price: '', cost: '', stock: '', minStock: '5' });
  const categoryNames = useMemo(() => Array.from(new Set([...categories.map((item) => item.name || ''), ...products.map((item) => item.category || '')].map((item) => item.trim()).filter(Boolean))).sort((a, b) => a.localeCompare(b)), [categories, products]);

  useEffect(() => {
    if (!draft.storeId && stores[0]?.id) setDraft((current) => ({ ...current, storeId: stores[0].id }));
  }, [stores]);

  async function addProduct(event: React.FormEvent) {
    event.preventDefault();
    if (!canEdit || !draft.name.trim() || !draft.storeId) return;
    setBusy(true);
    setMessage('');
    try {
      const categoryName = (draft.category === '__new__' ? draft.newCategory : draft.category).trim();
      const now = new Date().toISOString();
      const productId = `prd_${crypto.randomUUID()}`;
      const writes: Promise<unknown>[] = [];
      if (categoryName) {
        const categoryId = await stableId('cat', `${companyId}:${categoryName}`);
        writes.push(setDoc(doc(db, 'companies', companyId, 'categories', categoryId), { id: categoryId, sync_id: categoryId, company_id: companyId, name: categoryName, normalized_name: categoryName.toLowerCase(), created_at: now, updated_at: now, sync_status: 'pending', version: 1 }, { merge: true }));
      }
      writes.push(setDoc(doc(db, 'companies', companyId, 'products', productId), { id: productId, sync_id: productId, company_id: companyId, store_id: draft.storeId, name: draft.name.trim(), category: categoryName, price: Number(draft.price || 0), cost: Number(draft.cost || 0), stock_quantity: Number(draft.stock || 0), min_stock_level: Number(draft.minStock || 0), created_at: now, updated_at: now, sync_status: 'pending', version: 1 }));
      await Promise.all(writes);
      setDraft({ name: '', category: categoryName, newCategory: '', storeId: draft.storeId, price: '', cost: '', stock: '', minStock: '5' });
      setMessage('Product added.');
      setShowForm(false);
      onChanged();
    } catch (error) {
      setMessage(friendlyError(error, 'Unable to add the product. Please try again.'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section>
      <div className="section-head">
        <div>
          <h2>Inventory</h2>
          <p>Stock shown here is read from the active company collection.</p>
        </div>
        {canEdit ? <button className="primary" onClick={() => setShowForm((current) => !current)}><Plus size={16} /> {showForm ? 'Close form' : 'Add product'}</button> : <span className="pill"><Lock size={14} /> read only</span>}
      </div>
      {showForm && <form className="inventory-form" onSubmit={addProduct}>
        <label>Product name<input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} required /></label>
        <label>Store<select value={draft.storeId} onChange={(event) => setDraft({ ...draft, storeId: event.target.value })}>{stores.map((store) => <option key={store.id} value={store.id}>{store.name || store.id}</option>)}</select></label>
        <label>Category<select value={draft.category} onChange={(event) => setDraft({ ...draft, category: event.target.value, newCategory: event.target.value === '__new__' ? draft.newCategory : '' })}><option value="">Uncategorised</option>{categoryNames.map((category) => <option key={category} value={category}>{category}</option>)}<option value="__new__">+ Create new category</option></select></label>
        {draft.category === '__new__' && <label>New category<input autoFocus value={draft.newCategory} onChange={(event) => setDraft({ ...draft, newCategory: event.target.value })} required /></label>}
        <label>Price<input type="number" min="0" step="0.01" value={draft.price} onChange={(event) => setDraft({ ...draft, price: event.target.value })} required /></label>
        <label>Cost<input type="number" min="0" step="0.01" value={draft.cost} onChange={(event) => setDraft({ ...draft, cost: event.target.value })} /></label>
        <label>Opening stock<input type="number" min="0" step="any" value={draft.stock} onChange={(event) => setDraft({ ...draft, stock: event.target.value })} required /></label>
        <label>Minimum stock<input type="number" min="0" step="any" value={draft.minStock} onChange={(event) => setDraft({ ...draft, minStock: event.target.value })} required /></label>
        <button className="primary" disabled={busy || !draft.storeId}>{busy ? 'Saving...' : 'Save product'}</button>
      </form>}
      {message && <div className={`banner ${message === 'Product added.' ? 'notice' : 'error'}`}>{message}</div>}
      <div className="toolbar">
        <div className="search-box"><Search size={16} /><input value={queryText} onChange={(event) => onQuery(event.target.value)} placeholder="Search products" /></div>
      </div>
      <DataTable
        empty="No products found."
        columns={['Product', 'Category', 'Stock', 'Price']}
        rows={products.map((item) => [item.name || item.id, item.category || 'Uncategorised', String(item.stock_quantity ?? 0), `$${Number(item.price ?? 0).toFixed(2)}`])}
      />
    </section>
  );
}

function Team({ companyId, companyName, actorRole, stores, team, canEdit, onChanged }: { companyId: string; companyName: string; actorRole: Role; stores: StoreRow[]; team: TeamRow[]; canEdit: boolean; onChanged: () => void }) {
  const [draft, setDraft] = useState<EmployeeDraft>({ name: '', email: '', password: '', role: 'cashier', storeId: stores[0]?.id ?? '' });
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    setDraft((current) => current.storeId ? current : { ...current, storeId: stores[0]?.id ?? '' });
  }, [stores]);

  async function addMember(event: React.FormEvent) {
    event.preventDefault();
    if (!canEdit || !canCreateRole(actorRole, draft.role)) return;
    setBusy(true);
    setMessage('');
    const provisioningApp = initializeApp(firebaseConfig, `employee-provisioning-${Date.now()}`);
    const provisioningAuth = getAuth(provisioningApp);
    let createdEmployee: User | null = null;
    try {
      const cleanEmail = draft.email.trim().toLowerCase();
      const cleanName = draft.name.trim();
      const credential = await createUserWithEmailAndPassword(provisioningAuth, cleanEmail, draft.password);
      createdEmployee = credential.user;
      await updateProfile(credential.user, { displayName: cleanName });

      const uid = credential.user.uid;
      const registerId = `${draft.storeId}_register`;
      const now = new Date().toISOString();
      const batch = writeBatch(db);
      batch.set(doc(db, 'companies', companyId, 'users', uid), {
        id: uid,
        company_id: companyId,
        store_id: draft.storeId,
        register_id: registerId,
        name: cleanName,
        email: cleanEmail,
        role: draft.role,
        created_at: now,
        updated_at: now,
        sync_status: 'synced',
      });
      batch.set(doc(db, 'user_memberships', uid, 'companies', companyId), {
        company_id: companyId,
        company_name: companyName,
        user_id: uid,
        store_id: draft.storeId,
        register_id: registerId,
        email: cleanEmail,
        role: draft.role,
        updated_at: new Date(),
      });
      await batch.commit();
      createdEmployee = null;
      setDraft({ name: '', email: '', password: '', role: 'cashier', storeId: stores[0]?.id ?? '' });
      setMessage('Employee created.');
      onChanged();
    } catch (error) {
      if (createdEmployee) {
        try {
          await deleteUser(createdEmployee);
        } catch {
          // If rollback fails, surface the original Firestore/Auth error. An owner can retry with another email.
        }
      }
      setMessage(friendlyError(error, 'Unable to create employee. Please try again.'));
    } finally {
      await provisioningAuth.signOut().catch(() => undefined);
      await deleteApp(provisioningApp).catch(() => undefined);
      setBusy(false);
    }
  }

  async function updateRole(member: TeamRow, role: Role) {
    if (!canEdit || member.role === 'owner' || !canCreateRole(actorRole, role)) return;
    const batch = writeBatch(db);
    batch.update(doc(db, 'companies', companyId, 'users', member.id), { role, updated_at: new Date().toISOString() });
    batch.set(doc(db, 'user_memberships', member.id, 'companies', companyId), { role, company_id: companyId, user_id: member.id, updated_at: new Date() }, { merge: true });
    await batch.commit();
    onChanged();
  }

  const roleOptions: Role[] = actorRole === 'owner' ? ['admin', 'manager', 'cashier'] : ['manager', 'cashier'];

  return (
    <section>
      <div className="section-head">
        <div>
          <h2>Team & RBAC</h2>
          <p>Only users in this company path are listed. Owner accounts cannot be downgraded here.</p>
        </div>
      </div>
      {canEdit && (
        <form className="employee-form" onSubmit={addMember}>
          <input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} placeholder="Employee name" required />
          <input value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} placeholder="Email" type="email" required />
          <input value={draft.password} onChange={(event) => setDraft({ ...draft, password: event.target.value })} placeholder="Temporary password" type="password" minLength={6} required />
          <select value={draft.role} onChange={(event) => setDraft({ ...draft, role: event.target.value as Role })}>{roleOptions.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}</select>
          <select value={draft.storeId} onChange={(event) => setDraft({ ...draft, storeId: event.target.value })}>{stores.map((store) => <option key={store.id} value={store.id}>{store.name || store.id}</option>)}</select>
          <button className="primary" disabled={busy || !draft.storeId}><Plus size={16} /> {busy ? 'Creating...' : 'Create employee'}</button>
        </form>
      )}
      {message && <p className="banner notice"><CheckCircle2 size={16} />{message}</p>}
      <div className="team-list">
        {team.map((member) => (
          <div className="team-row" key={member.id}>
            <div>
              <strong>{member.name || member.email || member.id}</strong>
              <span>{member.email}</span>
            </div>
            <span className={`role-badge ${member.role ?? 'cashier'}`}>{roleLabel(member.role ?? 'cashier')}</span>
            <select disabled={!canEdit || member.role === 'owner'} value={member.role ?? 'cashier'} onChange={(event) => updateRole(member, event.target.value as Role)}>
              {member.role === 'owner' && <option value="owner">Owner</option>}
              {roleOptions.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
            </select>
          </div>
        ))}
        {team.length === 0 && <div className="empty">No team members found for this company.</div>}
      </div>
    </section>
  );
}

function DataTable({ columns, rows, empty }: { columns: string[]; rows: string[][]; empty: string }) {
  return (
    <div className="data-table">
      <div className="table-head" style={{ gridTemplateColumns: `repeat(${columns.length}, minmax(0, 1fr))` }}>
        {columns.map((column) => <span key={column}>{column}</span>)}
      </div>
      {rows.map((row, index) => (
        <div className="table-row" key={index} style={{ gridTemplateColumns: `repeat(${columns.length}, minmax(0, 1fr))` }}>
          {row.map((cell, cellIndex) => <span key={cellIndex}>{cell}</span>)}
        </div>
      ))}
      {rows.length === 0 && <div className="empty">{empty}</div>}
    </div>
  );
}

function Root() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [checkingPlatformRole, setCheckingPlatformRole] = useState(false);
  const [isPlatformAdmin, setIsPlatformAdmin] = useState(false);
  const [resolvedPlatformUid, setResolvedPlatformUid] = useState('');
  useEffect(() => onAuthStateChanged(auth, (next) => {
    setUser(next);
    setLoading(false);
  }), []);
  useEffect(() => {
    let active = true;
    if (!user) {
      setIsPlatformAdmin(false);
      setCheckingPlatformRole(false);
      setResolvedPlatformUid('');
      return () => { active = false; };
    }
    setCheckingPlatformRole(true);
    setResolvedPlatformUid('');
    getDoc(doc(db, 'platform_admins', user.uid))
      .then((snapshot) => {
        if (active) setIsPlatformAdmin(snapshot.exists() || user.uid === SUPER_ADMIN_UID);
      })
      .catch(() => {
        if (active) setIsPlatformAdmin(user.uid === SUPER_ADMIN_UID);
      })
      .finally(() => {
        if (active) {
          setResolvedPlatformUid(user.uid);
          setCheckingPlatformRole(false);
        }
      });
    return () => { active = false; };
  }, [user?.uid]);
  if (loading || checkingPlatformRole || (user && resolvedPlatformUid !== user.uid)) return <div className="center">Verifying account access...</div>;
  return user ? (isPlatformAdmin ? <SuperAdminApp user={user} /> : <AdminApp user={user} />) : <LoginScreen />;
}

createRoot(document.getElementById('root')!).render(<Root />);
