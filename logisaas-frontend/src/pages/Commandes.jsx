import { useEffect, useState } from 'react';
import { getCommandes, updateStatut } from '../api';

const STATUS_LABEL = {
  en_attente: { label: 'En attente', color: '#854F0B', bg: '#FAEEDA' },
  en_cours:   { label: 'En cours',   color: '#185FA5', bg: '#E6F1FB' },
  livree:     { label: 'Livrée',     color: '#3B6D11', bg: '#EAF3DE' },
  annulee:    { label: 'Annulée',    color: '#A32D2D', bg: '#FCEBEB' },
};

function StatusBadge({ status }) {
  const s = STATUS_LABEL[status] || { label: status, color: '#888', bg: '#eee' };
  return (
    <span style={{ background: s.bg, color: s.color, padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 500, display:'inline-flex', alignItems:'center', gap:5 }}>
      <span style={{ width:6, height:6, borderRadius:'50%', background:s.color, display:'inline-block' }}/>
      {s.label}
    </span>
  );
}

export default function Commandes({ onNouvelleCommande }) {
  const [commandes, setCommandes] = useState([]);
  const [search, setSearch]       = useState('');
  const [filtre, setFiltre]       = useState('tous');
  const [loading, setLoading]     = useState(true);

  useEffect(() => {
    getCommandes().then(r => { setCommandes(r.data); setLoading(false); });
  }, []);

  const filtered = commandes.filter(c => {
    const matchSearch = c.order_number.toLowerCase().includes(search.toLowerCase()) ||
      c.customer_name.toLowerCase().includes(search.toLowerCase());
    const matchFiltre = filtre === 'tous' || c.status === filtre;
    return matchSearch && matchFiltre;
  });

  const changerStatut = async (id, status) => {
    await updateStatut(id, status);
    setCommandes(prev => prev.map(c => c.id === id ? { ...c, status } : c));
  };

  if (loading) return <div style={{ color:'#888', padding:32 }}>Chargement...</div>;

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', marginBottom:16, gap:10, flexWrap:'wrap' }}>
        <div style={{ display:'flex', gap:8 }}>
          <button onClick={onNouvelleCommande} style={{ padding:'7px 16px', background:'#1D9E75', color:'#fff', border:'none', borderRadius:8, cursor:'pointer', fontSize:13 }}>
            + Nouvelle commande
          </button>
          {/* Filtres par statut */}
          {['tous','en_attente','en_cours','livree','annulee'].map(f => (
            <button key={f} onClick={() => setFiltre(f)} style={{
              padding:'6px 12px', borderRadius:8, fontSize:12, cursor:'pointer',
              background: filtre === f ? '#2c2c2a' : '#fff',
              color: filtre === f ? '#fff' : '#666',
              border: '0.5px solid #ccc'
            }}>
              {f === 'tous' ? 'Tous' : STATUS_LABEL[f]?.label}
            </button>
          ))}
        </div>
        <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Rechercher..."
          style={{ padding:'7px 12px', border:'0.5px solid #ccc', borderRadius:8, fontSize:13, width:200 }} />
      </div>

      <div style={{ background:'#fff', border:'0.5px solid #e0e0d8', borderRadius:12, overflow:'hidden' }}>
        <table style={{ width:'100%', borderCollapse:'collapse', fontSize:13 }}>
          <thead>
            <tr style={{ background:'#fafaf8' }}>
              {['N° commande','Client','Téléphone','Départ','Destination','Total','Statut','Changer statut'].map(h => (
                <th key={h} style={{ textAlign:'left', fontSize:11, color:'#888', fontWeight:500, padding:'10px 14px', borderBottom:'0.5px solid #e0e0d8' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map(c => (
              <tr key={c.id} style={{ borderBottom:'0.5px solid #f0f0e8' }}>
                <td style={{ padding:'10px 14px', fontWeight:500 }}>{c.order_number}</td>
                <td style={{ padding:'10px 14px' }}>{c.customer_name}</td>
                <td style={{ padding:'10px 14px', color:'#888' }}>{c.customer_phone}</td>
                <td style={{ padding:'10px 14px' }}>
                  <div style={{ fontSize:12 }}>
                    <div style={{ fontWeight:500, color:'#1D9E75' }}>📦 Boutique</div>
                    <div style={{ color:'#888', marginTop:2 }}>Rue de la Joie, Akwa</div>
                  </div>
                </td>
                <td style={{ padding:'10px 14px' }}>
                  <div style={{ fontSize:12 }}>
                    <div style={{ fontWeight:500, color:'#185FA5' }}>📍 {c.zone_name || 'Zone inconnue'}</div>
                    <div style={{ color:'#888', marginTop:2, maxWidth:150, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{c.delivery_address || '—'}</div>
                  </div>
                </td>
                <td style={{ padding:'10px 14px' }}>{Number(c.total_amount).toLocaleString('fr-FR')} F</td>
                <td style={{ padding:'10px 14px' }}><StatusBadge status={c.status} /></td>
                <td style={{ padding:'10px 14px' }}>
                  <select value={c.status} onChange={e => changerStatut(c.id, e.target.value)}
                    style={{ fontSize:12, padding:'4px 8px', border:'0.5px solid #ccc', borderRadius:6, cursor:'pointer' }}>
                    <option value="en_attente">En attente</option>
                    <option value="en_cours">En cours</option>
                    <option value="livree">Livrée</option>
                    <option value="annulee">Annulée</option>
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <div style={{ padding:32, textAlign:'center', color:'#888' }}>Aucune commande trouvée</div>
        )}
      </div>
    </div>
  );
}
