import { useEffect, useState } from 'react';
import { getProduits, createProduit } from '../api';

export default function Produits() {
  const [produits, setProduits]   = useState([]);
  const [search, setSearch]       = useState('');
  const [showForm, setShowForm]   = useState(false);
  const [form, setForm]           = useState({ name:'', sku:'', category:'', unit:'pièce', base_price:'', stock_quantity:'', stock_alert_threshold:'5', description:'' });
  const [saving, setSaving]       = useState(false);

  useEffect(() => { getProduits().then(r => setProduits(r.data)); }, []);

  const filtered = produits.filter(p =>
    p.name.toLowerCase().includes(search.toLowerCase()) ||
    p.sku.toLowerCase().includes(search.toLowerCase())
  );

  const submit = async () => {
    setSaving(true);
    try {
      const r = await createProduit(form);
      setProduits([r.data, ...produits]);
      setShowForm(false);
      setForm({ name:'', sku:'', category:'', unit:'pièce', base_price:'', stock_quantity:'', stock_alert_threshold:'5', description:'' });
    } catch(e) { alert(e.response?.data?.error || 'Erreur'); }
    setSaving(false);
  };

  const inp = { padding:'7px 10px', border:'0.5px solid #ccc', borderRadius:8, fontSize:13, width:'100%', boxSizing:'border-box' };
  const lbl = { fontSize:12, color:'#888', marginBottom:4, display:'block' };

  const stockColor = (p) => {
    if (p.stock_quantity <= p.stock_alert_threshold) return '#E24B4A';
    if (p.stock_quantity <= p.stock_alert_threshold * 2) return '#EF9F27';
    return '#1D9E75';
  };

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', marginBottom:16 }}>
        <button onClick={()=>setShowForm(!showForm)} style={{ padding:'7px 16px', background:'#1D9E75', color:'#fff', border:'none', borderRadius:8, cursor:'pointer', fontSize:13 }}>
          {showForm ? '✕ Annuler' : '+ Nouveau produit'}
        </button>
        <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Rechercher..." style={{ padding:'7px 12px', border:'0.5px solid #ccc', borderRadius:8, fontSize:13, width:200 }} />
      </div>

      {showForm && (
        <div style={{ background:'#fff', border:'0.5px solid #e0e0d8', borderRadius:12, padding:18, marginBottom:16 }}>
          <div style={{ fontWeight:500, fontSize:13, marginBottom:14 }}>Nouveau produit</div>
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:14, marginBottom:14 }}>
            <div><label style={lbl}>Nom *</label><input style={inp} value={form.name} onChange={e=>setForm({...form,name:e.target.value})} /></div>
            <div><label style={lbl}>SKU *</label><input style={inp} value={form.sku} onChange={e=>setForm({...form,sku:e.target.value})} placeholder="EX-PROD-001" /></div>
            <div><label style={lbl}>Catégorie</label><input style={inp} value={form.category} onChange={e=>setForm({...form,category:e.target.value})} /></div>
            <div><label style={lbl}>Unité</label><input style={inp} value={form.unit} onChange={e=>setForm({...form,unit:e.target.value})} /></div>
            <div><label style={lbl}>Prix de base (F CFA)</label><input style={inp} type="number" value={form.base_price} onChange={e=>setForm({...form,base_price:e.target.value})} /></div>
            <div><label style={lbl}>Stock initial</label><input style={inp} type="number" value={form.stock_quantity} onChange={e=>setForm({...form,stock_quantity:e.target.value})} /></div>
            <div><label style={lbl}>Seuil d'alerte stock</label><input style={inp} type="number" value={form.stock_alert_threshold} onChange={e=>setForm({...form,stock_alert_threshold:e.target.value})} /></div>
            <div style={{ gridColumn:'1/-1' }}><label style={lbl}>Description</label><textarea style={{...inp, minHeight:60}} value={form.description} onChange={e=>setForm({...form,description:e.target.value})} /></div>
          </div>
          <button onClick={submit} disabled={saving} style={{ padding:'8px 18px', background:'#1D9E75', color:'#fff', border:'none', borderRadius:8, cursor:'pointer', fontSize:13 }}>
            {saving ? 'Enregistrement...' : '✓ Créer le produit'}
          </button>
        </div>
      )}

      <div style={{ background:'#fff', border:'0.5px solid #e0e0d8', borderRadius:12, overflow:'hidden' }}>
        <table style={{ width:'100%', borderCollapse:'collapse', fontSize:13 }}>
          <thead>
            <tr style={{ background:'#fafaf8' }}>
              {['Produit','SKU','Catégorie','Prix','Stock','Seuil'].map(h=>(
                <th key={h} style={{ textAlign:'left', fontSize:11, color:'#888', fontWeight:500, padding:'10px 14px', borderBottom:'0.5px solid #e0e0d8' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map(p => (
              <tr key={p.id}>
                <td style={{ padding:'10px 14px', fontWeight:500 }}>{p.name}</td>
                <td style={{ padding:'10px 14px', color:'#888', fontFamily:'monospace', fontSize:12 }}>{p.sku}</td>
                <td style={{ padding:'10px 14px' }}><span style={{ background:'#f1efe8', color:'#5f5e5a', padding:'2px 8px', borderRadius:99, fontSize:11 }}>{p.category}</span></td>
                <td style={{ padding:'10px 14px' }}>{Number(p.base_price).toLocaleString('fr-FR')} F</td>
                <td style={{ padding:'10px 14px', fontWeight:500, color: stockColor(p) }}>{p.stock_quantity} {p.unit}</td>
                <td style={{ padding:'10px 14px', color:'#888' }}>{p.stock_alert_threshold}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
