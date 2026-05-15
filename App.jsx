import { useState } from 'react';
import Dashboard from './pages/Dashboard';
import Commandes from './pages/Commandes';
import NouvelleCommande from './pages/NouvelleCommande';
import Produits from './pages/Produits';

const NAV = [
  { id:'dashboard',  icon:'🏠', label:'Dashboard' },
  { id:'commandes',  icon:'🛒', label:'Commandes' },
  { id:'produits',   icon:'📦', label:'Produits' },
  { id:'livraisons', icon:'🚚', label:'Livraisons' },
  { id:'stock',      icon:'🏭', label:'Stock' },
];

export default function App() {
  const [page, setPage] = useState('dashboard');

  const goTo = (p) => setPage(p);

  return (
    <div style={{ display:'flex', height:'100vh', fontFamily:'system-ui, sans-serif', color:'#2c2c2a', background:'#f5f5f3' }}>

      {/* Sidebar */}
      <div style={{ width:220, background:'#fff', borderRight:'0.5px solid #e0e0d8', display:'flex', flexDirection:'column', flexShrink:0 }}>
        <div style={{ padding:'20px 16px 16px', borderBottom:'0.5px solid #e0e0d8' }}>
          <div style={{ fontSize:15, fontWeight:500 }}>🚛 LogiSaaS</div>
          <div style={{ fontSize:11, color:'#888', marginTop:2 }}>Douala Express Shop</div>
        </div>
        <nav style={{ padding:'12px 8px', flex:1 }}>
          {NAV.map(n => (
            <div
              key={n.id}
              onClick={() => goTo(n.id)}
              style={{
                display:'flex', alignItems:'center', gap:10,
                padding:'8px 10px', borderRadius:8, cursor:'pointer',
                fontSize:13, marginBottom:2,
                background: page === n.id ? '#f0f0e8' : 'transparent',
                fontWeight: page === n.id ? 500 : 400,
                color: page === n.id ? '#2c2c2a' : '#666',
              }}
            >
              <span>{n.icon}</span>{n.label}
            </div>
          ))}
        </nav>
        <div style={{ padding:12, borderTop:'0.5px solid #e0e0d8', fontSize:12, color:'#888' }}>
          Plan Pro · Actif
        </div>
      </div>

      {/* Main */}
      <div style={{ flex:1, display:'flex', flexDirection:'column', overflow:'hidden' }}>
        <div style={{ background:'#fff', borderBottom:'0.5px solid #e0e0d8', padding:'0 24px', height:52, display:'flex', alignItems:'center', justifyContent:'space-between', flexShrink:0 }}>
          <span style={{ fontSize:15, fontWeight:500 }}>
            {NAV.find(n=>n.id===page)?.label || 'Nouvelle commande'}
          </span>
          <div style={{ width:32, height:32, borderRadius:'50%', background:'#CECBF6', display:'flex', alignItems:'center', justifyContent:'center', fontSize:12, fontWeight:500, color:'#3C3489' }}>JP</div>
        </div>

        <div style={{ flex:1, overflowY:'auto', padding:'20px 24px' }}>
          {page === 'dashboard'          && <Dashboard />}
          {page === 'commandes'          && <Commandes onNouvelleCommande={() => goTo('nouvelle-commande')} />}
          {page === 'nouvelle-commande'  && <NouvelleCommande onRetour={() => goTo('commandes')} onSuccess={() => goTo('commandes')} />}
          {page === 'produits'           && <Produits />}
          {page === 'livraisons'         && <div style={{ color:'#888', padding:32 }}>Page Livraisons — à connecter</div>}
          {page === 'stock'              && <div style={{ color:'#888', padding:32 }}>Page Stock — à connecter</div>}
        </div>
      </div>
    </div>
  );
}
