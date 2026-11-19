import React, { useEffect, useMemo, useState } from 'react';
import { collection, doc, getDoc, getDocs, runTransaction, setDoc } from 'firebase/firestore';
import {
  ArrowLeft,
  ArrowRight,
  Check,
  FilePlus2,
  FileText,
  Plus,
  Printer,
  Save,
  Search,
  Settings,
  Trash2,
  UserRound,
  WalletCards,
} from 'lucide-react';
import { db } from './firebase';
import { friendlyError } from './errors';

type DocumentKind = 'invoice' | 'quotation';
type DocumentStatus = 'draft' | 'sent' | 'paid' | 'overdue' | 'accepted' | 'declined' | 'expired' | 'void';

type StoreOption = { id: string; name?: string; address?: string };
type ProductOption = { id: string; sync_id?: string; name?: string; price?: number };

type Customer = {
  id: string;
  company_id: string;
  store_id?: string;
  name: string;
  email?: string;
  phone?: string;
  address?: string;
  created_at?: string;
  updated_at?: string;
};

type InvoiceSettings = {
  invoice_prefix: string;
  quotation_prefix: string;
  default_currency: string;
  default_tax_rate: number;
  payment_terms_days: number;
  quote_valid_days: number;
  business_email: string;
  business_phone: string;
  business_address: string;
  tax_number: string;
  bank_details: string;
  logo_url: string;
};

export type DocumentPayment = {
  id: string;
  amount: number;
  date: string;
  method: string;
  reference?: string;
  recorded_by: string;
  created_at: string;
};

type AuditEvent = {
  id: string;
  action: string;
  user_id: string;
  occurred_at: string;
  status?: string;
  amount_paid?: number;
};

export type DocumentLine = {
  id: string;
  product_id?: string;
  description: string;
  quantity: number;
  rate: number;
};

export type CommercialDocument = {
  id: string;
  company_id: string;
  store_id?: string;
  kind: DocumentKind;
  number: string;
  status: DocumentStatus;
  issue_date: string;
  due_date: string;
  customer_name: string;
  customer_email?: string;
  customer_phone?: string;
  customer_address?: string;
  currency: string;
  items: DocumentLine[];
  subtotal: number;
  tax_rate: number;
  tax_amount: number;
  discount: number;
  shipping: number;
  total: number;
  amount_paid?: number;
  notes?: string;
  terms?: string;
  created_by: string;
  created_at: string;
  updated_at: string;
  converted_from?: string;
  customer_id?: string;
  payments?: DocumentPayment[];
};

type DocumentDraft = Omit<CommercialDocument, 'subtotal' | 'tax_amount' | 'total' | 'created_at' | 'updated_at'> & {
  created_at?: string;
  updated_at?: string;
};

type Props = {
  companyId: string;
  companyName: string;
  userId: string;
  canManageSettings: boolean;
  stores: StoreOption[];
  products: ProductOption[];
  documents: CommercialDocument[];
  onChanged: () => void;
};

const currencies = ['USD', 'ZWG', 'ZAR'];
const defaultSettings: InvoiceSettings = {
  invoice_prefix: 'INV',
  quotation_prefix: 'QUO',
  default_currency: 'USD',
  default_tax_rate: 0,
  payment_terms_days: 14,
  quote_valid_days: 30,
  business_email: '',
  business_phone: '',
  business_address: '',
  tax_number: '',
  bank_details: '',
  logo_url: '',
};

function dateInput(offsetDays = 0) {
  const date = new Date();
  date.setDate(date.getDate() + offsetDays);
  return date.toISOString().slice(0, 10);
}

function numberValue(value: string | number | undefined) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
}

function formatMoney(value: number, currency: string) {
  try {
    return new Intl.NumberFormat('en', { style: 'currency', currency, minimumFractionDigits: 2 }).format(value);
  } catch {
    return `${currency} ${value.toFixed(2)}`;
  }
}

function currencySummary(documents: CommercialDocument[], valueFor: (item: CommercialDocument) => number) {
  const totals = new Map<string, number>();
  documents.forEach((item) => totals.set(item.currency, (totals.get(item.currency) || 0) + valueFor(item)));
  if (!totals.size) return formatMoney(0, 'USD');
  return Array.from(totals, ([currency, value]) => formatMoney(value, currency)).join(' + ');
}

function totalsFor(draft: Pick<DocumentDraft, 'items' | 'tax_rate' | 'discount' | 'shipping'>) {
  const subtotal = draft.items.reduce((sum, item) => sum + numberValue(item.quantity) * numberValue(item.rate), 0);
  const discount = numberValue(draft.discount);
  const taxable = Math.max(0, subtotal - discount);
  const taxAmount = taxable * numberValue(draft.tax_rate) / 100;
  return { subtotal, taxAmount, total: Math.max(0, taxable + taxAmount + numberValue(draft.shipping)) };
}

function nextNumber(kind: DocumentKind, documents: CommercialDocument[], settings: InvoiceSettings) {
  const prefix = kind === 'invoice' ? settings.invoice_prefix : settings.quotation_prefix;
  const year = new Date().getFullYear();
  const matcher = new RegExp(`^${prefix}-${year}-(\\d+)$`);
  const greatest = documents.reduce((max, item) => {
    const matched = item.number?.match(matcher);
    return Math.max(max, matched ? Number(matched[1]) : 0);
  }, 0);
  return `${prefix}-${year}-${String(greatest + 1).padStart(4, '0')}`;
}

function freshDraft(kind: DocumentKind, props: Pick<Props, 'companyId' | 'userId' | 'stores' | 'documents'>, settings: InvoiceSettings): DocumentDraft {
  return {
    id: `doc_${crypto.randomUUID()}`,
    company_id: props.companyId,
    store_id: props.stores[0]?.id || '',
    kind,
    number: nextNumber(kind, props.documents, settings),
    status: 'draft',
    issue_date: dateInput(),
    due_date: dateInput(kind === 'invoice' ? settings.payment_terms_days : settings.quote_valid_days),
    customer_name: '',
    customer_email: '',
    customer_phone: '',
    customer_address: '',
    currency: settings.default_currency,
    items: [{ id: crypto.randomUUID(), description: '', quantity: 1, rate: 0 }],
    tax_rate: settings.default_tax_rate,
    discount: 0,
    shipping: 0,
    amount_paid: 0,
    notes: '',
    terms: kind === 'invoice' ? 'Payment is due by the date shown above.' : 'This quotation is valid until the date shown above.',
    created_by: props.userId,
    payments: [],
  };
}

function statusOptions(kind: DocumentKind): DocumentStatus[] {
  return kind === 'invoice' ? ['draft', 'sent', 'paid', 'overdue', 'void'] : ['draft', 'sent', 'accepted', 'declined', 'expired'];
}

export function DocumentsPage(props: Props) {
  const [kindFilter, setKindFilter] = useState<'all' | DocumentKind>('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [draft, setDraft] = useState<DocumentDraft | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [settings, setSettings] = useState<InvoiceSettings>(defaultSettings);
  const [panel, setPanel] = useState<'documents' | 'customers' | 'settings'>('documents');

  async function loadSupportingData() {
    const settingsRef = doc(db, 'companies', props.companyId, 'settings', 'invoicing');
    const [customerDocs, settingsDoc] = await Promise.all([
      getDocs(collection(db, 'companies', props.companyId, 'customers')).catch(() => null),
      getDoc(settingsRef).catch(() => null),
    ]);
    setCustomers((customerDocs?.docs ?? []).map((item) => ({ ...item.data(), id: item.id } as Customer)).filter((item) => !('deleted_at' in item) || !(item as Customer & { deleted_at?: string }).deleted_at).sort((a, b) => a.name.localeCompare(b.name)));
    if (settingsDoc?.exists()) setSettings({ ...defaultSettings, ...settingsDoc.data() } as InvoiceSettings);
  }

  useEffect(() => {
    loadSupportingData();
  }, [props.companyId]);

  const filtered = useMemo(() => props.documents.filter((item) => {
    if (kindFilter !== 'all' && item.kind !== kindFilter) return false;
    if (statusFilter !== 'all' && item.status !== statusFilter) return false;
    const haystack = `${item.number} ${item.customer_name} ${item.customer_email || ''}`.toLowerCase();
    return haystack.includes(search.trim().toLowerCase());
  }), [props.documents, kindFilter, statusFilter, search]);

  const unpaidInvoices = props.documents.filter((item) => item.kind === 'invoice' && !['paid', 'void'].includes(item.status));
  const openQuotes = props.documents.filter((item) => item.kind === 'quotation' && !['accepted', 'declined', 'expired'].includes(item.status));
  const invoiceBalance = currencySummary(unpaidInvoices, (item) => Math.max(0, item.total - numberValue(item.amount_paid)));
  const openQuoteValue = currencySummary(openQuotes, (item) => item.total);

  function openNew(kind: DocumentKind) {
    setMessage('');
    setDraft(freshDraft(kind, props, settings));
  }

  function openExisting(item: CommercialDocument) {
    setMessage('');
    setDraft({ ...item, items: item.items?.length ? item.items : [{ id: crypto.randomUUID(), description: '', quantity: 1, rate: 0 }] });
  }

  function convertToInvoice(item: CommercialDocument) {
    const converted = freshDraft('invoice', props, settings);
    setDraft({
      ...converted,
      store_id: item.store_id,
      customer_name: item.customer_name,
      customer_email: item.customer_email,
      customer_phone: item.customer_phone,
      customer_address: item.customer_address,
      currency: item.currency,
      items: item.items.map((line) => ({ ...line, id: crypto.randomUUID() })),
      tax_rate: item.tax_rate,
      discount: item.discount,
      shipping: item.shipping,
      notes: item.notes,
      terms: 'Payment is due by the date shown above.',
      converted_from: item.id,
    });
  }

  if (draft) {
    return <DocumentEditor {...props} customers={customers} settings={settings} draft={draft} setDraft={setDraft} busy={busy} setBusy={setBusy} message={message} setMessage={setMessage} onClose={() => setDraft(null)} />;
  }

  if (panel === 'customers') return <CustomersPanel companyId={props.companyId} userId={props.userId} stores={props.stores} customers={customers} documents={props.documents} onChanged={loadSupportingData} onClose={() => setPanel('documents')} />;
  if (panel === 'settings') return <SettingsPanel companyId={props.companyId} settings={settings} canEdit={props.canManageSettings} onChanged={loadSupportingData} onClose={() => setPanel('documents')} />;

  return (
    <div className="page-stack documents-page">
      <section className="document-hero">
        <div>
          <p className="eyebrow">Commercial documents</p>
          <h2>Invoices & quotations</h2>
          <p>Create, track, print, and convert customer documents without leaving your store workspace.</p>
        </div>
        <div className="document-actions">
          <button className="secondary" onClick={() => setPanel('customers')}><UserRound size={17} /> Customers</button>
          <button className="secondary" onClick={() => setPanel('settings')}><Settings size={17} /> Settings</button>
          <button className="secondary" onClick={() => openNew('quotation')}><FilePlus2 size={17} /> New quotation</button>
          <button className="primary" onClick={() => openNew('invoice')}><FilePlus2 size={17} /> New invoice</button>
        </div>
      </section>

      <section className="metrics-grid document-metrics">
        <div className="metric"><span>Total invoices</span><strong>{props.documents.filter((item) => item.kind === 'invoice').length}</strong><small>All saved invoices</small></div>
        <div className="metric warn"><span>Outstanding</span><strong>{invoiceBalance}</strong><small>Excludes paid and void</small></div>
        <div className="metric"><span>Open quotations</span><strong>{openQuotes.length}</strong><small>{openQuoteValue} potential value</small></div>
        <div className="metric ok"><span>Accepted</span><strong>{props.documents.filter((item) => item.kind === 'quotation' && item.status === 'accepted').length}</strong><small>Ready to invoice</small></div>
      </section>

      <section>
        <div className="document-toolbar">
          <div className="segmented document-tabs">
            {(['all', 'invoice', 'quotation'] as const).map((kind) => <button key={kind} className={kindFilter === kind ? 'active' : ''} onClick={() => setKindFilter(kind)}>{kind === 'all' ? 'All' : kind === 'invoice' ? 'Invoices' : 'Quotations'}</button>)}
          </div>
          <div className="search-box"><Search size={16} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search number or customer" /></div>
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
            <option value="all">All statuses</option>
            {['draft', 'sent', 'paid', 'overdue', 'accepted', 'declined', 'expired', 'void'].map((status) => <option key={status} value={status}>{status[0].toUpperCase() + status.slice(1)}</option>)}
          </select>
        </div>

        <div className="document-list">
          <div className="document-list-head"><span>Document</span><span>Customer</span><span>Date</span><span>Status</span><span>Total</span><span /></div>
          {filtered.map((item) => (
            <div className="document-list-row" key={item.id}>
              <button className="document-link" onClick={() => openExisting(item)}><FileText size={18} /><span><strong>{item.number}</strong><small>{item.kind === 'invoice' ? 'Invoice' : 'Quotation'}</small></span></button>
              <span>{item.customer_name || 'No customer'}</span>
              <span>{item.issue_date}</span>
              <span><span className={`status-chip ${item.status}`}>{item.status}</span></span>
              <strong>{formatMoney(item.total, item.currency)}</strong>
              <span className="row-actions"><button className="icon-button" title="Open document" onClick={() => openExisting(item)}><ArrowRight size={17} /></button>{item.kind === 'quotation' && <button className="small-action" onClick={() => convertToInvoice(item)}>Convert</button>}</span>
            </div>
          ))}
          {filtered.length === 0 && <div className="empty document-empty"><FileText size={28} /><strong>No documents found</strong><span>Create an invoice or quotation to get started.</span></div>}
        </div>
      </section>
    </div>
  );
}

function CustomersPanel({ companyId, userId, stores, customers, documents, onChanged, onClose }: { companyId: string; userId: string; stores: StoreOption[]; customers: Customer[]; documents: CommercialDocument[]; onChanged: () => void; onClose: () => void }) {
  const [draft, setDraft] = useState({ name: '', email: '', phone: '', address: '', store_id: stores[0]?.id || '' });
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const filtered = customers.filter((item) => `${item.name} ${item.email || ''} ${item.phone || ''}`.toLowerCase().includes(search.toLowerCase()));

  async function saveCustomer(event: React.FormEvent) {
    event.preventDefault();
    if (!draft.name.trim()) return;
    setBusy(true);
    setMessage('');
    try {
      const id = `cus_${crypto.randomUUID()}`;
      const now = new Date().toISOString();
      await setDoc(doc(db, 'companies', companyId, 'customers', id), { id, sync_id: id, company_id: companyId, store_id: draft.store_id, name: draft.name.trim(), email: draft.email.trim().toLowerCase(), phone: draft.phone.trim(), address: draft.address.trim(), created_by: userId, created_at: now, updated_at: now, sync_status: 'pending', version: 1 });
      setDraft({ name: '', email: '', phone: '', address: '', store_id: stores[0]?.id || '' });
      setMessage('Customer saved and available to invoices and the POS sync.');
      await onChanged();
    } catch (error) {
      setMessage(friendlyError(error, 'Unable to save the customer. Please try again.'));
    } finally {
      setBusy(false);
    }
  }

  function customerStats(customer: Customer) {
    const related = documents.filter((item) => item.customer_id === customer.id || (!item.customer_id && item.customer_name.toLowerCase() === customer.name.toLowerCase()));
    const invoices = related.filter((item) => item.kind === 'invoice' && item.status !== 'void');
    const outstanding = currencySummary(invoices, (item) => Math.max(0, item.total - numberValue(item.amount_paid)));
    return { count: related.length, outstanding };
  }

  return <div className="page-stack">
    <section className="panel-title"><button className="secondary" onClick={onClose}><ArrowLeft size={17} /> Documents</button><div><p className="eyebrow">Customer records</p><h2>Customers & statements</h2><p>Shared customer details and document balances in one place.</p></div></section>
    <section>
      <div className="section-head"><div><h2>Add customer</h2><p>New customers are stored in the same collection used by the POS sync.</p></div></div>
      <form className="customer-form" onSubmit={saveCustomer}>
        <label>Name<input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} required /></label>
        <label>Email<input type="email" value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} /></label>
        <label>Phone<input value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} /></label>
        <label>Store<select value={draft.store_id} onChange={(event) => setDraft({ ...draft, store_id: event.target.value })}>{stores.map((store) => <option key={store.id} value={store.id}>{store.name || store.id}</option>)}</select></label>
        <label className="span-two">Billing address<textarea value={draft.address} onChange={(event) => setDraft({ ...draft, address: event.target.value })} /></label>
        <button className="primary" disabled={busy}><Plus size={16} /> {busy ? 'Saving...' : 'Save customer'}</button>
      </form>
      {message && <div className={`banner ${message.startsWith('Customer saved') ? 'notice' : 'error'}`}>{message}</div>}
    </section>
    <section>
      <div className="section-head"><div><h2>Customer directory</h2><p>{customers.length} saved customer{customers.length === 1 ? '' : 's'}.</p></div><div className="search-box"><Search size={16} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search customers" /></div></div>
      <div className="customer-list"><div className="customer-list-head"><span>Customer</span><span>Contact</span><span>Documents</span><span>Outstanding</span></div>{filtered.map((customer) => { const stats = customerStats(customer); return <div className="customer-row" key={customer.id}><div><strong>{customer.name}</strong><small>{customer.address || 'No billing address'}</small></div><div><span>{customer.email || 'No email'}</span><small>{customer.phone || 'No phone'}</small></div><strong>{stats.count}</strong><strong>{stats.outstanding}</strong></div>; })}{!filtered.length && <div className="empty">No customers found.</div>}</div>
    </section>
  </div>;
}

function SettingsPanel({ companyId, settings, canEdit, onChanged, onClose }: { companyId: string; settings: InvoiceSettings; canEdit: boolean; onChanged: () => void; onClose: () => void }) {
  const [draft, setDraft] = useState(settings);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  async function saveSettings(event: React.FormEvent) {
    event.preventDefault();
    if (!canEdit) return;
    setBusy(true);
    setMessage('');
    try {
      await setDoc(doc(db, 'companies', companyId, 'settings', 'invoicing'), { ...draft, company_id: companyId, updated_at: new Date().toISOString() }, { merge: true });
      setMessage('Invoice settings saved.');
      await onChanged();
    } catch (error) {
      setMessage(friendlyError(error, 'Unable to save invoice settings. Please try again.'));
    } finally {
      setBusy(false);
    }
  }

  return <div className="page-stack">
    <section className="panel-title"><button className="secondary" onClick={onClose}><ArrowLeft size={17} /> Documents</button><div><p className="eyebrow">Company configuration</p><h2>Invoice settings</h2><p>Defaults and branding used on new invoices and quotations.</p></div></section>
    <section>
      {!canEdit && <div className="banner notice">Only owners and administrators can change company invoice settings.</div>}
      <form className="settings-form" onSubmit={saveSettings}>
        <div className="settings-group"><h3>Numbering and defaults</h3><div className="form-grid three">
          <label>Invoice prefix<input disabled={!canEdit} value={draft.invoice_prefix} onChange={(event) => setDraft({ ...draft, invoice_prefix: event.target.value.toUpperCase() })} /></label>
          <label>Quotation prefix<input disabled={!canEdit} value={draft.quotation_prefix} onChange={(event) => setDraft({ ...draft, quotation_prefix: event.target.value.toUpperCase() })} /></label>
          <label>Default currency<select disabled={!canEdit} value={draft.default_currency} onChange={(event) => setDraft({ ...draft, default_currency: event.target.value })}>{currencies.map((currency) => <option key={currency}>{currency}</option>)}</select></label>
          <label>Default tax rate (%)<input disabled={!canEdit} type="number" min="0" step="0.01" value={draft.default_tax_rate} onChange={(event) => setDraft({ ...draft, default_tax_rate: numberValue(event.target.value) })} /></label>
          <label>Invoice due after (days)<input disabled={!canEdit} type="number" min="0" value={draft.payment_terms_days} onChange={(event) => setDraft({ ...draft, payment_terms_days: numberValue(event.target.value) })} /></label>
          <label>Quote valid for (days)<input disabled={!canEdit} type="number" min="0" value={draft.quote_valid_days} onChange={(event) => setDraft({ ...draft, quote_valid_days: numberValue(event.target.value) })} /></label>
        </div></div>
        <div className="settings-group"><h3>Business identity</h3><div className="form-grid two">
          <label>Business email<input disabled={!canEdit} type="email" value={draft.business_email} onChange={(event) => setDraft({ ...draft, business_email: event.target.value })} /></label>
          <label>Business phone<input disabled={!canEdit} value={draft.business_phone} onChange={(event) => setDraft({ ...draft, business_phone: event.target.value })} /></label>
          <label>Tax or registration number<input disabled={!canEdit} value={draft.tax_number} onChange={(event) => setDraft({ ...draft, tax_number: event.target.value })} /></label>
          <label>Logo URL<input disabled={!canEdit} type="url" value={draft.logo_url} onChange={(event) => setDraft({ ...draft, logo_url: event.target.value })} placeholder="https://..." /></label>
          <label className="span-two">Business address<textarea disabled={!canEdit} value={draft.business_address} onChange={(event) => setDraft({ ...draft, business_address: event.target.value })} /></label>
          <label className="span-two">Bank and payment instructions<textarea disabled={!canEdit} value={draft.bank_details} onChange={(event) => setDraft({ ...draft, bank_details: event.target.value })} placeholder="Bank, account name, account number, mobile money details..." /></label>
        </div></div>
        {canEdit && <button className="primary settings-save" disabled={busy}><Save size={16} /> {busy ? 'Saving...' : 'Save settings'}</button>}
      </form>
      {message && <div className={`banner ${message.endsWith('saved.') ? 'notice' : 'error'}`}>{message}</div>}
    </section>
  </div>;
}

type EditorProps = Props & {
  customers: Customer[];
  settings: InvoiceSettings;
  draft: DocumentDraft;
  setDraft: React.Dispatch<React.SetStateAction<DocumentDraft | null>>;
  busy: boolean;
  setBusy: (value: boolean) => void;
  message: string;
  setMessage: (value: string) => void;
  onClose: () => void;
};

function DocumentEditor({ companyName, userId, stores, products, customers, settings, onChanged, draft, setDraft, busy, setBusy, message, setMessage, onClose }: EditorProps) {
  const totals = totalsFor(draft);
  const store = stores.find((item) => item.id === draft.store_id);
  const label = draft.kind === 'invoice' ? 'Invoice' : 'Quotation';
  const [payment, setPayment] = useState({ amount: '', method: 'Bank transfer', reference: '', date: dateInput() });
  const [savedPaymentCount, setSavedPaymentCount] = useState(draft.payments?.length || 0);
  const [auditEvents, setAuditEvents] = useState<AuditEvent[]>([]);
  const paidTotal = draft.payments?.length ? draft.payments.reduce((sum, item) => sum + item.amount, 0) : numberValue(draft.amount_paid);

  async function loadAudit() {
    if (!draft.created_at) return;
    const result = await getDocs(collection(db, 'companies', draft.company_id, 'documents', draft.id, 'events')).catch(() => null);
    setAuditEvents((result?.docs ?? []).map((item) => ({ ...item.data(), id: item.id } as AuditEvent)).sort((a, b) => b.occurred_at.localeCompare(a.occurred_at)));
  }

  useEffect(() => {
    loadAudit();
  }, [draft.id, draft.created_at]);

  function patch(values: Partial<DocumentDraft>) {
    setDraft((current) => current ? { ...current, ...values } : current);
  }

  function patchLine(id: string, values: Partial<DocumentLine>) {
    patch({ items: draft.items.map((item) => item.id === id ? { ...item, ...values } : item) });
  }

  function chooseProduct(lineId: string, productId: string) {
    const product = products.find((item) => item.id === productId || item.sync_id === productId);
    patchLine(lineId, { product_id: productId, description: product?.name || '', rate: numberValue(product?.price) });
  }

  function chooseCustomer(customerId: string) {
    const customer = customers.find((item) => item.id === customerId);
    patch({ customer_id: customerId, customer_name: customer?.name || '', customer_email: customer?.email || '', customer_phone: customer?.phone || '', customer_address: customer?.address || '' });
  }

  function addPayment() {
    const amount = numberValue(payment.amount);
    if (!amount) {
      setMessage('Enter a payment amount greater than zero.');
      return;
    }
    const entry: DocumentPayment = { id: crypto.randomUUID(), amount, date: payment.date, method: payment.method, reference: payment.reference.trim(), recorded_by: userId, created_at: new Date().toISOString() };
    const payments = [...(draft.payments || []), entry];
    const nextPaid = payments.reduce((sum, item) => sum + item.amount, 0);
    patch({ payments, amount_paid: nextPaid, status: nextPaid >= totals.total ? 'paid' : draft.status });
    setPayment({ amount: '', method: 'Bank transfer', reference: '', date: dateInput() });
    setMessage('Payment added. Save the invoice to confirm it.');
  }

  async function save() {
    if (!draft.number.trim() || !draft.customer_name.trim() || !draft.items.some((item) => item.description.trim())) {
      setMessage('Add a document number, customer, and at least one described line item.');
      return;
    }
    setBusy(true);
    setMessage('');
    try {
      const now = new Date().toISOString();
      const isNew = !draft.created_at;
      const documentRef = doc(db, 'companies', draft.company_id, 'documents', draft.id);
      const eventRef = doc(collection(documentRef, 'events'));
      const payload = await runTransaction(db, async (transaction) => {
        let documentNumber = draft.number;
        if (isNew) {
          const counterRef = doc(db, 'companies', draft.company_id, 'counters', 'commercial_documents');
          const counter = await transaction.get(counterRef);
          const field = draft.kind === 'invoice' ? 'invoice_next' : 'quotation_next';
          const next = Math.max(1, Number(counter.data()?.[field] || 1));
          const configuredPrefix = draft.kind === 'invoice' ? settings.invoice_prefix : settings.quotation_prefix;
          const prefix = configuredPrefix.trim().toUpperCase() || (draft.kind === 'invoice' ? 'INV' : 'QUO');
          documentNumber = `${prefix}-${new Date().getFullYear()}-${String(next).padStart(4, '0')}`;
          transaction.set(counterRef, { company_id: draft.company_id, [field]: next + 1, updated_at: now }, { merge: true });
        }
        const amountPaid = draft.payments?.length ? draft.payments.reduce((sum, item) => sum + item.amount, 0) : numberValue(draft.amount_paid);
        const nextStatus = draft.kind === 'invoice' && !['paid', 'void'].includes(draft.status) && draft.due_date < dateInput() && amountPaid < totals.total ? 'overdue' : draft.status;
        const nextPayload: CommercialDocument = {
          ...draft,
          number: documentNumber,
          status: nextStatus,
          customer_email: draft.customer_email || '',
          customer_phone: draft.customer_phone || '',
          customer_address: draft.customer_address || '',
          notes: draft.notes || '',
          terms: draft.terms || '',
          subtotal: totals.subtotal,
          tax_amount: totals.taxAmount,
          total: totals.total,
          amount_paid: amountPaid,
          payments: draft.payments || [],
          created_at: draft.created_at || now,
          updated_at: now,
        };
        transaction.set(documentRef, nextPayload);
        const hasNewPayment = (draft.payments?.length || 0) > savedPaymentCount;
        transaction.set(eventRef, { action: isNew ? 'created' : hasNewPayment ? 'payment_recorded' : 'updated', document_id: draft.id, company_id: draft.company_id, user_id: userId, occurred_at: now, status: nextStatus, amount_paid: amountPaid });
        if (isNew && draft.converted_from) {
          const sourceRef = doc(db, 'companies', draft.company_id, 'documents', draft.converted_from);
          transaction.update(sourceRef, { status: 'accepted', converted_to: draft.id, updated_at: now });
          transaction.set(doc(collection(sourceRef, 'events')), { action: 'converted_to_invoice', document_id: draft.converted_from, target_id: draft.id, company_id: draft.company_id, user_id: userId, occurred_at: now });
        }
        return nextPayload;
      });
      setDraft(payload);
      setSavedPaymentCount(payload.payments?.length || 0);
      setMessage(`${label} saved.`);
      onChanged();
      setTimeout(loadAudit, 0);
    } catch (error) {
      setMessage(friendlyError(error, `Unable to save ${label.toLowerCase()}. Please try again.`));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="document-editor">
      <div className="editor-topbar no-print">
        <button className="secondary" onClick={onClose}><ArrowLeft size={17} /> Back to documents</button>
        <div><span className="editor-kind">{label}</span><strong>{draft.number}</strong></div>
        <div className="document-actions">
          <button className="secondary" onClick={() => window.print()}><Printer size={17} /> Print / PDF</button>
          <button className="primary" disabled={busy} onClick={save}><Save size={17} /> {busy ? 'Saving...' : `Save ${label.toLowerCase()}`}</button>
        </div>
      </div>
      {message && <div className={`banner no-print ${message.endsWith('saved.') ? 'notice' : 'error'}`}>{message.endsWith('saved.') && <Check size={16} />}{message}</div>}

      <div className="editor-layout">
        <section className="document-form no-print">
          <div className="form-section-head"><span>01</span><div><h3>Document details</h3><p>Number, dates, store, and status.</p></div></div>
          <div className="form-grid two">
            <label>{label} number<input value={draft.number} onChange={(event) => patch({ number: event.target.value })} /></label>
            <label>Status<select value={draft.status} onChange={(event) => patch({ status: event.target.value as DocumentStatus })}>{statusOptions(draft.kind).map((status) => <option key={status} value={status}>{status[0].toUpperCase() + status.slice(1)}</option>)}</select></label>
            <label>Issue date<input type="date" value={draft.issue_date} onChange={(event) => patch({ issue_date: event.target.value })} /></label>
            <label>{draft.kind === 'invoice' ? 'Due date' : 'Valid until'}<input type="date" value={draft.due_date} onChange={(event) => patch({ due_date: event.target.value })} /></label>
            <label>Store<select value={draft.store_id} onChange={(event) => patch({ store_id: event.target.value })}>{stores.map((item) => <option key={item.id} value={item.id}>{item.name || item.id}</option>)}</select></label>
            <label>Currency<select value={draft.currency} onChange={(event) => patch({ currency: event.target.value })}>{currencies.map((currency) => <option key={currency}>{currency}</option>)}</select></label>
          </div>

          <div className="form-section-head"><span>02</span><div><h3>Bill to</h3><p>Customer contact and billing information.</p></div></div>
          <div className="form-grid two">
            <label className="span-two">Saved customer<select value={draft.customer_id || ''} onChange={(event) => chooseCustomer(event.target.value)}><option value="">Enter customer manually</option>{customers.map((customer) => <option key={customer.id} value={customer.id}>{customer.name}{customer.email ? ` — ${customer.email}` : ''}</option>)}</select></label>
            <label>Customer or business<input value={draft.customer_name} onChange={(event) => patch({ customer_name: event.target.value })} placeholder="Acme Trading" /></label>
            <label>Email<input type="email" value={draft.customer_email} onChange={(event) => patch({ customer_email: event.target.value })} placeholder="accounts@example.com" /></label>
            <label>Phone<input value={draft.customer_phone} onChange={(event) => patch({ customer_phone: event.target.value })} placeholder="+263 ..." /></label>
            <label className="span-two">Billing address<textarea value={draft.customer_address} onChange={(event) => patch({ customer_address: event.target.value })} placeholder="Street, city, country" /></label>
          </div>

          <div className="form-section-head"><span>03</span><div><h3>Line items</h3><p>Select inventory or add a custom product or service.</p></div></div>
          <div className="line-editor">
            {draft.items.map((item, index) => (
              <div className="line-editor-row" key={item.id}>
                <span className="line-number">{String(index + 1).padStart(2, '0')}</span>
                <div className="line-description">
                  <select value={item.product_id || ''} onChange={(event) => chooseProduct(item.id, event.target.value)}><option value="">Custom item</option>{products.map((product) => <option key={product.id} value={product.id}>{product.name || product.id}</option>)}</select>
                  <input value={item.description} onChange={(event) => patchLine(item.id, { description: event.target.value })} placeholder="Description" />
                </div>
                <label>Qty<input type="number" min="0" step="any" value={item.quantity} onChange={(event) => patchLine(item.id, { quantity: numberValue(event.target.value) })} /></label>
                <label>Rate<input type="number" min="0" step="0.01" value={item.rate} onChange={(event) => patchLine(item.id, { rate: numberValue(event.target.value) })} /></label>
                <strong>{formatMoney(item.quantity * item.rate, draft.currency)}</strong>
                <button className="icon-button danger" title="Remove line" disabled={draft.items.length === 1} onClick={() => patch({ items: draft.items.filter((line) => line.id !== item.id) })}><Trash2 size={16} /></button>
              </div>
            ))}
            <button className="add-line" onClick={() => patch({ items: [...draft.items, { id: crypto.randomUUID(), description: '', quantity: 1, rate: 0 }] })}><Plus size={16} /> Add line item</button>
          </div>

          <div className="form-section-head"><span>04</span><div><h3>Totals & notes</h3><p>Apply adjustments and payment information.</p></div></div>
          <div className="form-grid three">
            <label>Discount ({draft.currency})<input type="number" min="0" step="0.01" value={draft.discount} onChange={(event) => patch({ discount: numberValue(event.target.value) })} /></label>
            <label>Tax rate (%)<input type="number" min="0" step="0.01" value={draft.tax_rate} onChange={(event) => patch({ tax_rate: numberValue(event.target.value) })} /></label>
            <label>Shipping ({draft.currency})<input type="number" min="0" step="0.01" value={draft.shipping} onChange={(event) => patch({ shipping: numberValue(event.target.value) })} /></label>
            <label className="span-two">Notes<textarea value={draft.notes} onChange={(event) => patch({ notes: event.target.value })} placeholder="Thank you for your business." /></label>
            <label className="span-two">Terms<textarea value={draft.terms} onChange={(event) => patch({ terms: event.target.value })} /></label>
          </div>
          {draft.kind === 'invoice' && <div className="payment-panel">
            <div className="payment-heading"><div><WalletCards size={18} /><span><strong>Payments</strong><small>{formatMoney(paidTotal, draft.currency)} received</small></span></div><strong>{formatMoney(Math.max(0, totals.total - paidTotal), draft.currency)} due</strong></div>
            {(draft.payments || []).map((item) => <div className="payment-row" key={item.id}><span>{item.date}</span><span>{item.method}</span><span>{item.reference || 'No reference'}</span><strong>{formatMoney(item.amount, draft.currency)}</strong></div>)}
            <div className="payment-form">
              <input type="date" value={payment.date} onChange={(event) => setPayment({ ...payment, date: event.target.value })} />
              <select value={payment.method} onChange={(event) => setPayment({ ...payment, method: event.target.value })}><option>Bank transfer</option><option>Cash</option><option>Card</option><option>Mobile money</option><option>Other</option></select>
              <input value={payment.reference} onChange={(event) => setPayment({ ...payment, reference: event.target.value })} placeholder="Reference" />
              <input type="number" min="0" step="0.01" value={payment.amount} onChange={(event) => setPayment({ ...payment, amount: event.target.value })} placeholder="Amount" />
              <button className="secondary" type="button" onClick={addPayment}><Plus size={16} /> Add</button>
            </div>
          </div>}
          {draft.created_at && <div className="audit-panel">
            <div className="payment-heading"><div><FileText size={18} /><span><strong>Activity</strong><small>Immutable document history</small></span></div></div>
            {auditEvents.map((event) => <div className="audit-row" key={event.id}><span className="status-chip">{event.action.replace(/_/g, ' ')}</span><span>{new Date(event.occurred_at).toLocaleString()}</span><small>{event.user_id === userId ? 'You' : event.user_id}</small></div>)}
            {!auditEvents.length && <div className="empty">No activity recorded yet.</div>}
          </div>}
        </section>

        <DocumentPreview companyName={companyName} store={store} settings={settings} draft={draft} totals={totals} />
      </div>
    </div>
  );
}

function DocumentPreview({ companyName, store, settings, draft, totals }: { companyName: string; store?: StoreOption; settings: InvoiceSettings; draft: DocumentDraft; totals: ReturnType<typeof totalsFor> }) {
  const label = draft.kind === 'invoice' ? 'INVOICE' : 'QUOTATION';
  const paid = draft.payments?.length ? draft.payments.reduce((sum, item) => sum + item.amount, 0) : numberValue(draft.amount_paid);
  const balance = Math.max(0, totals.total - paid);
  return (
    <aside className="document-preview" aria-label={`${label} preview`}>
      <div className="preview-page">
        <div className="preview-header">
          <div className="preview-brand">{settings.logo_url ? <img src={settings.logo_url} alt="Company logo" /> : <span>{companyName.slice(0, 2).toUpperCase()}</span>}<div><strong>{companyName}</strong><small>{store?.name || 'Company workspace'}</small></div></div>
          <div className="preview-title"><h2>{label}</h2><strong>{draft.number}</strong></div>
        </div>
        <div className="preview-addresses">
          <div><span>FROM</span><strong>{store?.name || companyName}</strong><p>{settings.business_address || store?.address || companyName}</p><p>{settings.business_email}{settings.business_phone ? ` · ${settings.business_phone}` : ''}</p>{settings.tax_number && <p>Tax no. {settings.tax_number}</p>}</div>
          <div><span>BILL TO</span><strong>{draft.customer_name || 'Customer name'}</strong><p>{draft.customer_address || 'Customer billing address'}</p><p>{draft.customer_email}</p></div>
          <div className="preview-dates"><span>ISSUED</span><strong>{draft.issue_date}</strong><span>{draft.kind === 'invoice' ? 'DUE' : 'VALID UNTIL'}</span><strong>{draft.due_date}</strong></div>
        </div>
        <div className="preview-lines">
          <div className="preview-line head"><span>Description</span><span>Qty</span><span>Rate</span><span>Amount</span></div>
          {draft.items.map((item) => <div className="preview-line" key={item.id}><span>{item.description || 'Item description'}</span><span>{item.quantity}</span><span>{formatMoney(item.rate, draft.currency)}</span><strong>{formatMoney(item.quantity * item.rate, draft.currency)}</strong></div>)}
        </div>
        <div className="preview-summary">
          <div />
          <dl>
            <div><dt>Subtotal</dt><dd>{formatMoney(totals.subtotal, draft.currency)}</dd></div>
            {draft.discount > 0 && <div><dt>Discount</dt><dd>-{formatMoney(draft.discount, draft.currency)}</dd></div>}
            {draft.tax_rate > 0 && <div><dt>Tax ({draft.tax_rate}%)</dt><dd>{formatMoney(totals.taxAmount, draft.currency)}</dd></div>}
            {draft.shipping > 0 && <div><dt>Shipping</dt><dd>{formatMoney(draft.shipping, draft.currency)}</dd></div>}
            <div className="preview-total"><dt>Total</dt><dd>{formatMoney(totals.total, draft.currency)}</dd></div>
            {draft.kind === 'invoice' && <div className="preview-balance"><dt>Balance due</dt><dd>{formatMoney(balance, draft.currency)}</dd></div>}
          </dl>
        </div>
        {(draft.notes || draft.terms || settings.bank_details) && <div className="preview-notes">{draft.notes && <div><span>NOTES</span><p>{draft.notes}</p></div>}<div>{draft.terms && <><span>TERMS</span><p>{draft.terms}</p></>}{settings.bank_details && <><span>PAYMENT DETAILS</span><p>{settings.bank_details}</p></>}</div></div>}
        <div className="preview-footer"><span>{companyName}</span><span>{draft.customer_email || 'Generated with ShopaFlow'}</span></div>
      </div>
    </aside>
  );
}
