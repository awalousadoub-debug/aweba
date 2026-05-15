import { useEffect, useState } from 'react';
import { getLivraisons, createLivraison, getCommandes } from '../api';

const STATUS_LABEL = {
  assignee:   { label: 'Assignée',   color: '#854F0B', bg: '#FAEEDA' },
  en_cours:   { label: 'En cours',   color: '#185FA5', bg: '#E6F1FB' },
  livree:     { label: 'Livrée',     color: '#3B6D11', bg: '#EAF3DE' },
  echec:      { label: 'Échec',      color: '#A32D2D', bg: '#FCEBEB' },
};

const LIVREURS = [
  { id: 'bbbbbbbb-0000-4000-b000-000000000003', name: 'Alain Nguema' },
  { id: 'bbbbbbbb-0000-4000-b000-000000000006', name: 'Samuel Nkomo' },
];

const ZONES = [
  { id: 'cccccccc-0000-4000-c000-000000000001', name: 'Akwa' },
  { id: 'cccccccc-0000-4000-c000-000000000002', name: 'Bonanjo' },
  { id: 'cccccccc-0000-4000-c000-000000000003', name: 'Bonapriso' },
  { id: 'cccccccc-0000-4000-c000-000000000004', name: 'Makepe' },
];

function StatusBadge({ status }) {
  const s = STATUS_LABEL[status] || { label: status, color: '#888', bg: '#eee' };
  return (
    <span style={{ background: s.bg, color: s.color, padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 500, display: 'inline-flex', alignItems: 'center', gap: 5 }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color, display: 'inline-block' }} />
      {s.label}
    </span>
  );
}

export default function Livraisons() {
  const [livraisons, setLivraisons] = useState([]);
  const [commandes,  setCommandes]  = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [showForm,   setShowForm]   = useState(false);
  const [form,       setForm]       = useState({ order_id: '', driver_id: LIVREURS[0].id, zone_id: ZONES[0].id });
  const [saving,     setSaving]     = useState(false);
  const [error,      setError]      = useState('');

  useEffect(() => {
    Promise.all([getLivraisons(), getCommandes()]).then(([l, c]) => {
      setLivraisons(l.data);
      // Seulement les commandes confirmées ou expédiées sans livraison
      setCommandes(c.data.filter(c => ['confirmee', 'brouillon'].includes(c.status)));
      setLoading(false);
    });
  }, []);

  const submit = async () => {
    if (!form.order_id) return setError('Sélectionne une commande.');
    setSaving(true); setError('');
    try {
      const r = await createLivraison(form);
      setLivraisons([r.data, ...livraisons]);
      setShowForm(false);
      setForm({ order_id: '', driver_id: LIVREURS[0].id, zone_id: ZONES[0].id });
    } catch (e) {
      setError(e.response?.data?.error || 'Erreur.');
    }
    setSaving(false);
  };

  const inp = { padding: '7px 10px', border: '0.5px solid #ccc', borderRadius: 8, fontSize: 13, width: '100%', boxSizing: 'border-box' };
  const lbl = { fontSize: 12, color: '#888', marginBottom: 4, display: 'block' };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
        <button onClick={() => setShowForm(!showForm)} style={{ padding: '7px 16px', background: '#1D9E75', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}>
          {showForm ? '✕ Annuler' : '+ Assigner une livraison'}
        </button>
      </div>

      {showForm && (
        <div style={{ background: '#fff', border: '0.5px solid #e0e0d8', borderRadius: 12, padding: 18, marginBottom: 16 }}>
          <div style={{ fontWeight: 500, fontSize: 13, marginBottom: 14 }}>Nouvelle livraison</div>
          {error && <div style={{ background: '#FCEBEB', color: '#A32D2D', padding: '8px 12px', borderRadius: 8, marginBottom: 12, fontSize: 13 }}>{error}</div>}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14, marginBottom: 14 }}>
            <div>
              <label style={lbl}>Commande</label>
              <select style={inp} value={form.order_id} onChange={e => {
                const cmd = commandes.find(c => c.id === e.target.value);
                setForm({ ...form, order_id: e.target.value, zone_id: cmd?.delivery_zone_id || ZONES[0].id });
              }}>
                <option value="">— Choisir une commande —</option>
                {commandes.map(c => (
                  <option key={c.id} value={c.id}>
                    {c.order_number} — {c.customer_name} ({Number(c.total_amount).toLocaleString('fr-FR')} F)
                  </option>
                ))}
              </select>
              {commandes.length === 0 && (
                <div style={{ fontSize: 11, color: '#EF9F27', marginTop: 4 }}>Aucune commande disponible à livrer.</div>
              )}
            </div>
            <div>
              <label style={lbl}>Livreur</label>
              <select style={inp} value={form.driver_id} onChange={e => setForm({ ...form, driver_id: e.target.value })}>
                {LIVREURS.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
              </select>
            </div>
            <div>
              <label style={lbl}>Zone</label>
              <select style={inp} value={form.zone_id} onChange={e => setForm({ ...form, zone_id: e.target.value })}>
                {ZONES.map(z => <option key={z.id} value={z.id}>{z.name}</option>)}
              </select>
            </div>
          </div>
          <button onClick={submit} disabled={saving} style={{ padding: '8px 18px', background: '#1D9E75', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}>
            {saving ? 'Assignation...' : '✓ Assigner'}
          </button>
        </div>
      )}

      {loading ? (
        <div style={{ color: '#888', padding: 32 }}>Chargement...</div>
      ) : (
        <div style={{ background: '#fff', border: '0.5px solid #e0e0d8', borderRadius: 12, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ background: '#fafaf8' }}>
                {['Commande', 'Client', 'Livreur', 'Zone', 'Statut', 'Code confirmation', 'Date'].map(h => (
                  <th key={h} style={{ textAlign: 'left', fontSize: 11, color: '#888', fontWeight: 500, padding: '10px 14px', borderBottom: '0.5px solid #e0e0d8' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {livraisons.map(l => (
                <tr key={l.id} style={{ borderBottom: '0.5px solid #f0f0e8' }}>
                  <td style={{ padding: '10px 14px', fontWeight: 500 }}>{l.order_number}</td>
                  <td style={{ padding: '10px 14px' }}>{l.customer_name}</td>
                  <td style={{ padding: '10px 14px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{ width: 26, height: 26, borderRadius: '50%', background: '#CECBF6', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, color: '#3C3489', fontWeight: 500 }}>
                        {l.driver_name?.split(' ').map(n => n[0]).join('')}
                      </div>
                      {l.driver_name || '—'}
                    </div>
                  </td>
                  <td style={{ padding: '10px 14px', color: '#888' }}>{l.zone_name}</td>
                  <td style={{ padding: '10px 14px' }}><StatusBadge status={l.status} /></td>
                  <td style={{ padding: '10px 14px' }}>
                    <code style={{ fontSize: 13, background: '#f5f5f3', padding: '3px 8px', borderRadius: 6 }}>{l.confirmation_code}</code>
                  </td>
                  <td style={{ padding: '10px 14px', color: '#888', fontSize: 12 }}>
                    {new Date(l.created_at).toLocaleDateString('fr-FR')}
                  </td>
                </tr>
              ))}
              {livraisons.length === 0 && (
                <tr><td colSpan={7} style={{ padding: 32, textAlign: 'center', color: '#888' }}>Aucune livraison</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
