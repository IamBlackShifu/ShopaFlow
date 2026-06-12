import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  updateProfile,
  User,
} from 'firebase/auth';
import {
  collection,
  collectionGroup,
  doc,
  getDocs,
  limit,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import {
  AlertTriangle,
  BarChart3,
  Boxes,
  Building2,
  CheckCircle2,
  Lock,
  LogOut,
  Plus,
  RefreshCw,
  ReceiptText,
  Search,
  ShieldCheck,
  Store,
  Users,
} from 'lucide-react';
import { auth, db, functions } from './firebase';
import './styles.css';

type Role = 'owner' | 'admin' | 'manager' | 'cashier';
type Tab = 'overview' | 'sales' | 'stores' | 'inventory' | 'team';

type Membership = {
  companyId: string;
  userId: string;
  role: Role;
  companyName: string;
};

type StoreRow = { id: string; company_id?: string; name?: string; address?: string; created_at?: string };
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
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [ownerName, setOwnerName] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [storeName, setStoreName] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      if (mode === 'login') {
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
        await Promise.all([
          setDoc(doc(db, 'companies', companyId), {
            id: companyId,
            name: cleanCompanyName,
            owner_user_id: credential.user.uid,
            plan: 'local',
            subscription_status: 'local',
            created_at: now,
            updated_at: now,
            sync_status: 'pending',
          }),
          setDoc(doc(db, 'companies', companyId, 'stores', storeId), {
            id: storeId,
            company_id: companyId,
            name: cleanStoreName,
            created_at: now,
            updated_at: now,
            sync_status: 'pending',
          }),
          setDoc(doc(db, 'companies', companyId, 'users', credential.user.uid), {
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
          }),
          setDoc(doc(db, 'user_memberships', credential.user.uid, 'companies', companyId), {
            company_id: companyId,
            company_name: cleanCompanyName,
            user_id: credential.user.uid,
            store_id: storeId,
            register_id: registerId,
            email: credential.user.email,
            role: 'owner',
            updated_at: new Date(),
          }),
        ]);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to sign in');
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
          <h1>{mode === 'login' ? 'Welcome back' : 'Create company workspace'}</h1>
          <p>{mode === 'login' ? 'Manage stores, stock, and staff with company-scoped access.' : 'This creates the first owner account for a company.'}</p>
        </div>
        <div className="segmented">
          <button type="button" className={mode === 'login' ? 'active' : ''} onClick={() => setMode('login')}>Sign in</button>
          <button type="button" className={mode === 'register' ? 'active' : ''} onClick={() => setMode('register')}>Register</button>
        </div>
        {mode === 'register' && (
          <div className="field-grid">
            <label>Company name<input value={companyName} onChange={(event) => setCompanyName(event.target.value)} required /></label>
            <label>Owner name<input value={ownerName} onChange={(event) => setOwnerName(event.target.value)} required /></label>
            <label>Main store name<input value={storeName} onChange={(event) => setStoreName(event.target.value)} placeholder="Defaults to company name" /></label>
          </div>
        )}
        <label>Email<input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required /></label>
        <label>Password<input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required minLength={6} /></label>
        {error && <div className="banner error"><AlertTriangle size={16} />{error}</div>}
        <button className="primary" disabled={busy}>{busy ? 'Working...' : mode === 'login' ? 'Sign in' : 'Create owner account'}</button>
      </form>
    </main>
  );
}

function useMembership(user: User | null) {
  const [membership, setMembership] = useState<Membership | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
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
      setMembership({
        companyId,
        userId: user.uid,
        role: (data.role ?? 'cashier') as Role,
        companyName: data.company_name || companyId,
      });
      setLoading(false);
    }
    load().catch(() => {
      if (active) setLoading(false);
    });
    return () => {
      active = false;
    };
  }, [user]);

  return { membership, loading };
}

function AdminApp({ user }: { user: User }) {
  const { membership, loading } = useMembership(user);
  const [tab, setTab] = useState<Tab>('overview');
  const [stores, setStores] = useState<StoreRow[]>([]);
  const [products, setProducts] = useState<ProductRow[]>([]);
  const [sales, setSales] = useState<SaleRow[]>([]);
  const [saleItems, setSaleItems] = useState<SaleItemRow[]>([]);
  const [team, setTeam] = useState<TeamRow[]>([]);
  const [queryText, setQueryText] = useState('');
  const [loadingData, setLoadingData] = useState(false);
  const [dataError, setDataError] = useState('');

  async function loadWorkspace(nextMembership = membership) {
    if (!nextMembership) return;
    setLoadingData(true);
    setDataError('');
    try {
      const base = doc(db, 'companies', nextMembership.companyId);
      const [storeDocs, productDocs, saleDocs, saleItemDocs, teamDocs] = await Promise.all([
        getDocs(collection(base, 'stores')),
        getDocs(collection(base, 'products')),
        getDocs(collection(base, 'sales')),
        getDocs(collection(base, 'sale_items')),
        getDocs(collection(base, 'users')),
      ]);
      const onlyCompany = <T extends { company_id?: string }>(row: T) => !row.company_id || row.company_id === nextMembership.companyId;
      setStores(storeDocs.docs.map((item) => ({ ...item.data(), id: item.id } as StoreRow)).filter(onlyCompany).sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      setProducts(productDocs.docs.map((item) => {
        const data = item.data() as ProductRow;
        return { ...data, local_id: data.id, id: item.id };
      }).filter(onlyCompany).filter((item) => !item.deleted_at).sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      setSales(saleDocs.docs.map((item) => {
        const data = item.data() as SaleRow;
        return { ...data, local_id: data.id, id: item.id };
      }).filter(onlyCompany).filter((item) => !item.deleted_at));
      setSaleItems(saleItemDocs.docs.map((item) => ({ ...item.data(), id: item.id } as SaleItemRow)).filter(onlyCompany).filter((item) => !item.deleted_at));
      setTeam(teamDocs.docs.map((item) => ({ ...item.data(), id: item.id } as TeamRow)).filter((item) => item.company_id === nextMembership.companyId).sort((a, b) => roleRank[b.role || 'cashier'] - roleRank[a.role || 'cashier'] || (a.name || '').localeCompare(b.name || '')));
    } catch (error) {
      setDataError(error instanceof Error ? error.message : 'Unable to load dashboard data.');
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
  if (!membership) return <div className="center"><Lock size={24} /> No company membership found for this account.</div>;
  if (membership.role === 'cashier') return <div className="center"><Lock size={24} /> Cashiers use the POS app. Admin dashboard access requires manager or higher.</div>;

  const nav = [
    ['overview', BarChart3, 'Overview'],
    ['sales', ReceiptText, 'Sales'],
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
        {tab === 'stores' && <Stores companyId={membership.companyId} stores={stores} canEdit={canManageCompany(membership.role)} onChanged={() => loadWorkspace()} />}
        {tab === 'inventory' && <Inventory products={filteredProducts} canEdit={canManageInventory(membership.role)} queryText={queryText} onQuery={setQueryText} />}
        {tab === 'team' && <Team companyId={membership.companyId} actorRole={membership.role} stores={stores} team={team} canEdit={canManageCompany(membership.role)} onChanged={() => loadWorkspace()} />}
      </main>
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

function Inventory({ products, canEdit, queryText, onQuery }: { products: ProductRow[]; canEdit: boolean; queryText: string; onQuery: (value: string) => void }) {
  return (
    <section>
      <div className="section-head">
        <div>
          <h2>Inventory</h2>
          <p>Stock shown here is read from the active company collection.</p>
        </div>
        {!canEdit && <span className="pill"><Lock size={14} /> read only</span>}
      </div>
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

function Team({ companyId, actorRole, stores, team, canEdit, onChanged }: { companyId: string; actorRole: Role; stores: StoreRow[]; team: TeamRow[]; canEdit: boolean; onChanged: () => void }) {
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
    try {
      const createEmployee = httpsCallable(functions, 'createEmployee');
      await createEmployee({ companyId, storeId: draft.storeId, name: draft.name, email: draft.email, password: draft.password, role: draft.role });
      setDraft({ name: '', email: '', password: '', role: 'cashier', storeId: stores[0]?.id ?? '' });
      setMessage('Employee created.');
      onChanged();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to create employee.');
    } finally {
      setBusy(false);
    }
  }

  async function updateRole(member: TeamRow, role: Role) {
    if (!canEdit || member.role === 'owner' || !canCreateRole(actorRole, role)) return;
    await Promise.all([
      updateDoc(doc(db, 'companies', companyId, 'users', member.id), { role, updated_at: new Date().toISOString() }),
      setDoc(doc(db, 'user_memberships', member.id, 'companies', companyId), { role, company_id: companyId, user_id: member.id, updated_at: new Date() }, { merge: true }),
    ]);
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
  useEffect(() => onAuthStateChanged(auth, (next) => {
    setUser(next);
    setLoading(false);
  }), []);
  if (loading) return <div className="center">Starting...</div>;
  return user ? <AdminApp user={user} /> : <LoginScreen />;
}

createRoot(document.getElementById('root')!).render(<Root />);
