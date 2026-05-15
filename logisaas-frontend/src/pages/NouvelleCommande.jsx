import { useEffect, useState } from 'react';
import { getProduits, createCommande } from '../api';

const ZONES = [
  { id: 'cccccccc-0000-4000-c000-000000000001', name: 'Akwa', fee: 500 },
  { id: 'cccccccc-0000-4000-c000-000000000002', name: 'Bonanjo', fee: 700 },
  { id: 'cccccccc-0000-4000-c000-000000000003', name: 'Bonapriso', fee: 800 },
  { id: 'cccccccc-0000-4000-c000-000000000004', name: 'Makepe', fee: 1200 },
];

export default function NouvelleCommande({ onRetour, onSuccess }) {
  const [produits, setProduits] = useState([]);
  const [items, setItems]       = useState([{ product_id:'', quantity:1, unit_price:0, product_name:'', product_sku:'', stock_max:0 }]);
  const [form, setForm]         = useState({ customer_name:'', customer_phone:'', customer_email:'', delivery_address:'', delivery_zone_id:ZONES[0].id, payment_method:'mobile_money' });
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState('');

  useEffect(() => { getProduits().then(r => setProduits(r.data)); }, []);

  const updateItem = (i, field, val) => {
    const next = [...items];
    next[i][field] = val;

    if (field === 'product_id') {
      const p = produits.find(p => p.id === val);
      if (p) {
        next[i].unit_price   = p.base_price;
        next[i].product_name = p.name;
        next[i].product_sku  = p.sku;
        next[i].stock_max    = p.stock_quantity;
        next[i].quantity     = 1;
        next[i].stock_error  = '';
      }
    }

    if (field === 'quantity') {
      const qty = parseInt(val) || 0;
      const max = next[i].stock_max;
      if (max > 0 && qty > max) {
        next[i].stock_error = `⚠ Quantité insuffisante — stock disponible : ${max} unité(s)`;
      } else {
        next[i].stock_error = '';
      }
      next[i].quantity = qty;
    }

    setItems(next);
  };

  const addItem    = () => setItems([...items, { product_id:'', quantity:1, unit_price:0, product_name:'', product_sku:'', stock_max:0, stock_error:'' }]);
  const removeItem = (i) => setItems(items.filter((_, idx) => idx !== i));

  const zone     = ZONES.find(z => z.id === form.delivery_zone_id);
  const subtotal = items.reduce((s, i) => s + (i.unit_price * i.quantity), 0);
  const total    = subtotal + (zone?.fee || 0);

  const hasStockError = items.some(i => i.stock_error);

  const submit = async () => {
    if (!form.customer_name || !form.customer_phone) return setError('Nom et téléphone obligatoires.');
    if (items.some(i => !i.product_id))              return setError('Sélectionnez un produit pour chaque ligne.');
    if (hasStockError)                               return setError('Corrige les quantités avant d\'enregistrer.');
    setSaving(true); setError('');
    try {
      await createCommande({ ...form, items });
      onSuccess();
    } catch (e) {
      setError(e.response?.data?.error || 'Erreur lors de l\'enregistrement.');
    }
    setSaving(false);
  };

  const inp = { padding:'7px 10px', border:'0.5px solid #ccc', borderRadius:8, fontSize:13, width:'100%', boxSizing:'border-box' };
  const lbl = { fontSize:12, color:'#888', marginBottom:4, display:'block' };

  return (
    <div>
      <div style={{ display:'flex', alignItems:'center', gap:10, marginBottom:20 }}>
        <button onClick={onRetour} style={{ padding:'6px 14px', border:'0.5px solid #ccc', borderRadius:8, background:'#fff', cursor:'pointer', fontSize:13 }}>← Retour</button>
        <span style={{ fontSize:15, fontWeight:500 }}>Nouvelle commande</span>
      </div>

      {error && (
        <div style={{ background:'#FCEBEB', color:'#A32D2D', padding:'10px 14px', borderRadius:8, marginBottom:16, fontSize:13 }}>
          {error}
        </div>
      )}

      {/* Infos client */}
      <div style={{ background:'#fff', border:'0.5px solid #e0e0d8', borderRadius:12, padding:18, marginBottom:16 }}>
        <div style={{ fontWeight:500, fontSize:13, marginBottom:14, paddingBottom:10, borderBottom:'0.5px solid #f0f0e8' }}>Informations client</div>
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:14 }}>
          <div><label style={lbl}>Nom complet *</label><input style={inp} value={form.customer_name} onChange={e=>setForm({...form,customer_name:e.target.value})} placeholder="Ngono Béatrice" /></div>
          <div><label style={lbl}>Téléphone *</label><input style={inp} value={form.customer_phone} onChange={e=>setForm({...form,customer_phone:e.target.value})} placeholder="+237 6XX XXX XXX" /></div>
          <div><label style={lbl}>Email</label><input style={inp} value={form.customer_email} onChange={e=>setForm({...form,customer_email:e.target.value})} placeholder="client@email.com" /></div>
          <div>
            <label style={lbl}>Zone de livraison</label>
            <select style={inp} value={form.delivery_zone_id} onChange={e=>setForm({...form,delivery_zone_id:e.target.value})}>
              {ZONES.map(z => <option key={z.id} value={z.id}>{z.name} ({z.fee.toLocaleString('fr-FR')} F)</option>)}
            </select>
          </div>
          <div style={{ gridColumn:'1/-1' }}><label style={lbl}>Adresse de livraison</label><input style={inp} value={form.delivery_address} onChange={e=>setForm({...form,delivery_address:e.target.value})} placeholder="Rue, quartier, repère..." /></div>
        </div>
      </div>

      {/* Produits */}
      <div style={{ background:'#fff', border:'0.5px solid #e0e0d8', borderRadius:12, padding:18, marginBottom:16 }}>
        <div style={{ fontWeight:500, fontSize:13, marginBottom:14, paddingBottom:10, borderBottom:'0.5px solid #f0f0e8' }}>Produits commandés</div>
        {items.map((item, i) => (
          <div key={i} style={{ marginBottom:12 }}>
            <div style={{ display:'grid', gridTemplateColumns:'1fr 120px 100px auto', gap:10, alignItems:'end' }}>
              <div>
                <label style={lbl}>Produit</label>
                <select style={inp} value={item.product_id} onChange={e=>updateItem(i,'product_id',e.target.value)}>
                  <option value="">— Choisir —</option>
                  {produits.map(p => (
                    <option key={p.id} value={p.id}>
                      {p.name} — {Number(p.base_price).toLocaleString('fr-FR')} F (stock: {p.stock_quantity})
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label style={lbl}>Quantité {item.stock_max > 0 && <span style={{ color:'#1D9E75' }}>/ {item.stock_max} dispo</span>}</label>
                <input
                  style={{ ...inp, borderColor: item.stock_error ? '#E24B4A' : '#ccc' }}
                  type="number" min="1"
                  max={item.stock_max || undefined}
                  value={item.quantity}
                  onChange={e=>updateItem(i,'quantity',e.target.value)}
                />
              </div>
              <div>
                <label style={lbl}>Sous-total</label>
                <div style={{ padding:'7px 10px', background:'#f5f5f3', borderRadius:8, fontSize:13 }}>
                  {(item.unit_price * item.quantity).toLocaleString('fr-FR')} F
                </div>
              </div>
              <button onClick={()=>removeItem(i)} disabled={items.length===1}
                style={{ padding:'7px 10px', border:'0.5px solid #f0c0c0', borderRadius:8, background:'#fff', color:'#E24B4A', cursor:'pointer', fontSize:13, marginBottom:0 }}>
                ✕
              </button>
            </div>
            {/* Alerte stock insuffisant */}
            {item.stock_error && (
              <div style={{ marginTop:6, padding:'8px 12px', background:'#FCEBEB', color:'#A32D2D', borderRadius:8, fontSize:12, display:'flex', alignItems:'center', gap:6 }}>
                🚫 {item.stock_error}
              </div>
            )}
          </div>
        ))}
        <button onClick={addItem} style={{ padding:'6px 14px', border:'0.5px solid #ccc', borderRadius:8, background:'#fff', cursor:'pointer', fontSize:13, marginTop:4 }}>
          + Ajouter un produit
        </button>
      </div>

      {/* Paiement + Récap */}
      <div style={{ background:'#fff', border:'0.5px solid #e0e0d8', borderRadius:12, padding:18, marginBottom:16 }}>
        <div style={{ fontWeight:500, fontSize:13, marginBottom:14, paddingBottom:10, borderBottom:'0.5px solid #f0f0e8' }}>Paiement</div>
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:14 }}>
          <div>
            <label style={lbl}>Mode de paiement</label>
            <select style={inp} value={form.payment_method} onChange={e=>setForm({...form,payment_method:e.target.value})}>
              <option value="mobile_money">Mobile Money</option>
              <option value="cash_livraison">Cash à la livraison</option>
              <option value="virement">Virement bancaire</option>
            </select>
          </div>
          <div style={{ padding:'10px 0' }}>
            <div style={{ fontSize:12, color:'#888' }}>Sous-total : {subtotal.toLocaleString('fr-FR')} F</div>
            <div style={{ fontSize:12, color:'#888', marginTop:4 }}>Livraison ({zone?.name}) : {(zone?.fee||0).toLocaleString('fr-FR')} F</div>
            <div style={{ fontSize:16, fontWeight:600, marginTop:8, color:'#1D9E75' }}>Total : {total.toLocaleString('fr-FR')} F</div>
          </div>
        </div>
      </div>

      <div style={{ display:'flex', justifyContent:'flex-end', gap:10 }}>
        <button onClick={onRetour} style={{ padding:'8px 18px', border:'0.5px solid #ccc', borderRadius:8, background:'#fff', cursor:'pointer', fontSize:13 }}>Annuler</button>
        <button onClick={submit} disabled={saving || hasStockError} style={{
          padding:'8px 18px', background: hasStockError ? '#ccc' : '#1D9E75',
          color:'#fff', border:'none', borderRadius:8, cursor: hasStockError ? 'not-allowed' : 'pointer', fontSize:13
        }}>
          {saving ? 'Enregistrement...' : '✓ Enregistrer la commande'}
        </button>
      </div>
    </div>
  );
}
