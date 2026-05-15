import { useEffect, useState } from 'react';
import { getDashboard, getCommandes } from '../api';

const STATUS_LABEL = {
  brouillon:  { label: 'Brouillon',  color: '#888780', bg: '#F1EFE8' },
  confirmee:  { label: 'Confirmée',  color: '#854F0B', bg: '#FAEEDA' },
  expediee:   { label: 'Expédiée',   color: '#185FA5', bg: '#E6F1FB' },
  livree:     { label: 'Livrée',     color: '#3B6D11', bg: '#EAF3DE' },
  annulee:    { label: 'Annulée',    color: '#A32D2D', bg: '#FCEBEB' },
};

function StatusBadge({ status }) {
  const s = STATUS_LABEL[status] || { label: status, color: '#888', bg: '#eee' };
  return (
    <span style={{
      background: s.bg, color: s.color,
      padding: '3px 10px', borderRadius: 99,
      fontSize: 12, fontWeight: 500,
      display: 'inline-flex', alignItems: 'center', gap: 5,
    }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color, display: 'inline-block' }} />
      {s.label}
    </span>
  );
}

export default function Dashboard() {
  const [kpi, setKpi]           = useState(null);
  const [commandes, setCommandes] = useState([]);

  useEffect(() => {
    getDashboard().then(r => setKpi(r.data));
    getCommandes().then(r => setCommandes(r.data.slice(0, 5)));
  }, []);

  return (
    <div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12, marginBottom: 24 }}>
        {[
          { label: 'Commandes du mois', value: kpi?.commandes_mois ?? '—' },
          { label: 'Chiffre d\'affaires', value: kpi ? `${kpi.chiffre_affaires.toLocaleString('fr-FR')} F` : '—' },
          { label: 'Livraisons en cours', value: kpi?.livraisons_cours ?? '—' },
          { label: 'Stock critique', value: kpi?.stock_critique ?? '—' },
        ].map(({ label, value }) => (
          <div key={label} style={{ background: '#f5f5f3', borderRadius: 8, padding: '14px 16px' }}>
            <div style={{ fontSize: 12, color: '#888', marginBottom: 6 }}>{label}</div>
            <div style={{ fontSize: 22, fontWeight: 500 }}>{value}</div>
          </div>
        ))}
      </div>

      <div style={{ background: '#fff', border: '0.5px solid #e0e0d8', borderRadius: 12, padding: '16px 18px' }}>
        <div style={{ fontWeight: 500, fontSize: 13, marginBottom: 14 }}>Dernières commandes</div>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr>{['N° commande','Client','Zone','Total','Statut'].map(h => (
              <th key={h} style={{ textAlign:'left', fontSize:11, color:'#888', fontWeight:500, padding:'0 8px 8px', borderBottom:'0.5px solid #e0e0d8' }}>{h}</th>
            ))}</tr>
          </thead>
          <tbody>
            {commandes.map(c => (
              <tr key={c.id}>
                <td style={{ padding:'9px 8px', borderBottom:'0.5px solid #f0f0e8', fontWeight:500 }}>{c.order_number}</td>
                <td style={{ padding:'9px 8px', borderBottom:'0.5px solid #f0f0e8' }}>{c.customer_name}</td>
                <td style={{ padding:'9px 8px', borderBottom:'0.5px solid #f0f0e8', color:'#888' }}>{c.zone_name || '—'}</td>
                <td style={{ padding:'9px 8px', borderBottom:'0.5px solid #f0f0e8' }}>{Number(c.total_amount).toLocaleString('fr-FR')} F</td>
                <td style={{ padding:'9px 8px', borderBottom:'0.5px solid #f0f0e8' }}><StatusBadge status={c.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
