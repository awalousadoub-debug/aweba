import { useEffect, useState } from 'react';
import { getProduits, getStock, entreeStock } from '../api';

export default function Stock() {
  const [produits,   setProduits]   = useState([]);
  const [mouvements, setMouvements] = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [showForm,   setShowForm]   = useState(false);
  const [type,       setType]       = useState('entree'); // 'entree' ou 'sortie'
  const [form,       setForm]       = useState({ product_id: '', quantity: 1, reason: '' });
  const [saving,     setSaving]     = useState(false);
  const [error,      setError]      = useState('');

  useEffect(() => {
    Promise.all([getProduits(), getStock()]).then(([p, s]) => {
      setProduits(p.data);
      setMouvements(s.data);
      setLoading(false);
    });
  }, []);

  const stockColor = (p) => {
    if (p.stock_quantity <= p.stock_alert_threshold) return '#E24B4A';
    if (p.stock_quantity <= p.stock_alert_threshold * 2) return '#EF9F27';
    return '#1D9E75';
  };

  const barWidth = (p) => {
    const max = Math.max(p.stock_quantity, p.stock_alert_threshold * 5);
    return Math.min(100, (p.stock_quantity / max) * 100);
  };

  const barColor = (p) => {
    if (p.stock_quantity <= p.stock_alert_threshold) return '#E24B4A';
    if (p.stock_quantity <= p.stock_alert_threshold * 2) return '#EF9F27';
    return '#1D9E75';
  };

  const submit = async () => {
    if (!form.product_id || !form.quantity) return setError('Sélectionne un produit et une quantité.');
    setSaving(true); setError('');
    try {
      await entreeStock({ ...form, quantity: parseInt(form.quantity) });
      const [p, s] = await Promise.all([getProduits(), getStock()]);
      setProduits(p.data);
      setMouvements(s.data);
      setShowForm(false);
      setForm({ product_id: '', quantity: 1, reason: '' });
    } catch (e) {
      setError(e.response?.data?.error || 'Erreur.');
    }
    setSaving(false);
  };

  const inp = { padding: '7px 10px', border: '0.5px solid #ccc', borderRadius: 8, fontSize: 13, width: '100%', boxSizing: 'border-box' };
  const lbl = { fontSize: 12, color: '#888', marginBottom: 4, display: 'block' };

  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <button onClick={() => { setShowForm(true); setType('entree'); }} style={{ padding: '7px 16px', background: '#1D9E75', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}>
          + Entrée de stock
        </button>
        <button onClick={() => { setShowForm(true); setType('sortie'); }} style={{ padding: '7px 16px', background: '#fff', color: '#2c2c2a', border: '0.5px solid #ccc', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}>
          − Sortie manuelle
        </button>
        {showForm && (
          <button onClick={() => setShowForm(false)} style={{ padding: '7px 16px', background: '#fff', color: '#888', border: '0.5px solid #ccc', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}>
            ✕ Annuler
          </button>
        )}
      </div>

      {showForm && (
        <div style={{ background: '#fff', border: '0.5px solid #e0e0d8', borderRadius: 12, padding: 18, marginBottom: 16 }}>
          <div style={{ fontWeight: 500, fontSize: 13, marginBottom: 14 }}>
            {type === 'entree' ? '📥 Entrée de stock' : '📤 Sortie manuelle'}
          </div>
          {error && <div style={{ background: '#FCEBEB', color: '#A32D2D', padding: '8px 12px', borderRadius: 8, marginBottom: 12, fontSize: 13 }}>{error}</div>}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14, marginBottom: 14 }}>
            <div>
              <label style={lbl}>Produit</label>
              <select style={inp} value={form.product_id} onChange={e => setForm({ ...form, product_id: e.target.value })}>
                <option value="">— Choisir —</option>
                {produits.map(p => <option key={p.id} value={p.id}>{p.name} (stock: {p.stock_quantity})</option>)}
              </select>
            </div>
            <div>
              <label style={lbl}>Quantité</label>
              <input style={inp} type="number" min="1" value={form.quantity} onChange={e => setForm({ ...form, quantity: e.target.value })} />
            </div>
            <div>
              <label style={lbl}>Motif</label>
              <input style={inp} value={form.reason} onChange={e => setForm({ ...form, reason: e.target.value })} placeholder="Ex: Réapprovisionnement" />
            </div>
          </div>
          <button onClick={submit} disabled={saving} style={{ padding: '8px 18px', background: '#1D9E75', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}>
            {saving ? 'Enregistrement...' : '✓ Enregistrer'}
          </button>
        </div>
      )}

      {loading ? <div style={{ color: '#888', padding: 32 }}>Chargement...</div> : (
        <>
          {/* Niveaux de stock */}
          <div style={{ background: '#fff', border: '0.5px solid #e0e0d8', borderRadius: 12, padding: 18, marginBottom: 16 }}>
            <div style={{ fontWeight: 500, fontSize: 13, marginBottom: 14 }}>Niveaux de stock</div>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: '#fafaf8' }}>
                  {['Produit', 'Stock actuel', 'Seuil alerte', 'Niveau', 'État'].map(h => (
                    <th key={h} style={{ textAlign: 'left', fontSize: 11, color: '#888', fontWeight: 500, padding: '10px 14px', borderBottom: '0.5px solid #e0e0d8' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {produits.map(p => (
                  <tr key={p.id} style={{ borderBottom: '0.5px solid #f0f0e8' }}>
                    <td style={{ padding: '10px 14px', fontWeight: 500 }}>{p.name}</td>
                    <td style={{ padding: '10px 14px', fontWeight: 500, color: stockColor(p) }}>{p.stock_quantity} {p.unit}</td>
                    <td style={{ padding: '10px 14px', color: '#888' }}>{p.stock_alert_threshold}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <div style={{ width: 120, height: 6, background: '#f0f0e8', borderRadius: 99, overflow: 'hidden' }}>
                        <div style={{ width: `${barWidth(p)}%`, height: '100%', background: barColor(p), borderRadius: 99 }} />
                      </div>
                    </td>
                    <td style={{ padding: '10px 14px' }}>
                      {p.stock_quantity <= p.stock_alert_threshold ? (
                        <span style={{ color: '#E24B4A', fontSize: 12, fontWeight: 500 }}>⚠ Critique</span>
                      ) : p.stock_quantity <= p.stock_alert_threshold * 2 ? (
                        <span style={{ color: '#EF9F27', fontSize: 12, fontWeight: 500 }}>⚡ Moyen</span>
                      ) : (
                        <span style={{ color: '#1D9E75', fontSize: 12, fontWeight: 500 }}>✓ OK</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Historique mouvements */}
          <div style={{ background: '#fff', border: '0.5px solid #e0e0d8', borderRadius: 12, padding: 18 }}>
            <div style={{ fontWeight: 500, fontSize: 13, marginBottom: 14 }}>Historique des mouvements</div>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: '#fafaf8' }}>
                  {['Produit', 'Type', 'Quantité', 'Avant', 'Après', 'Motif', 'Date'].map(h => (
                    <th key={h} style={{ textAlign: 'left', fontSize: 11, color: '#888', fontWeight: 500, padding: '10px 14px', borderBottom: '0.5px solid #e0e0d8' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {mouvements.map(m => (
                  <tr key={m.id} style={{ borderBottom: '0.5px solid #f0f0e8' }}>
                    <td style={{ padding: '10px 14px', fontWeight: 500 }}>{m.product_name}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <span style={{
                        background: m.movement_type === 'entree' ? '#EAF3DE' : '#FCEBEB',
                        color: m.movement_type === 'entree' ? '#3B6D11' : '#A32D2D',
                        padding: '2px 8px', borderRadius: 99, fontSize: 11, fontWeight: 500
                      }}>
                        {m.movement_type === 'entree' ? '📥 Entrée' : '📤 Sortie'}
                      </span>
                    </td>
                    <td style={{ padding: '10px 14px', fontWeight: 500, color: m.movement_type === 'entree' ? '#1D9E75' : '#E24B4A' }}>
                      {m.movement_type === 'entree' ? '+' : ''}{m.quantity_delta}
                    </td>
                    <td style={{ padding: '10px 14px', color: '#888' }}>{m.quantity_before}</td>
                    <td style={{ padding: '10px 14px', color: '#888' }}>{m.quantity_after}</td>
                    <td style={{ padding: '10px 14px', color: '#888', fontSize: 12 }}>{m.reason || '—'}</td>
                    <td style={{ padding: '10px 14px', color: '#888', fontSize: 12 }}>
                      {new Date(m.created_at).toLocaleDateString('fr-FR')}
                    </td>
                  </tr>
                ))}
                {mouvements.length === 0 && (
                  <tr><td colSpan={7} style={{ padding: 32, textAlign: 'center', color: '#888' }}>Aucun mouvement</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
