import { useState } from 'react';
import { login } from '../api';

export default function Login({ onLogin }) {
  const [form, setForm]   = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async () => {
    if (!form.email || !form.password) return setError('Remplis tous les champs.');
    setLoading(true); setError('');
    try {
      const r = await login(form);
      localStorage.setItem('token', r.data.token);
      localStorage.setItem('user', JSON.stringify(r.data.user));
      onLogin(r.data.user);
    } catch (e) {
      setError(e.response?.data?.error || 'Erreur de connexion.');
    }
    setLoading(false);
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center',
      justifyContent: 'center', background: '#f5f5f3'
    }}>
      <div style={{
        background: '#fff', border: '0.5px solid #e0e0d8',
        borderRadius: 16, padding: '40px 36px', width: 360,
      }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{ fontSize: 28, marginBottom: 8 }}>🚛</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>LogiSaaS</div>
          <div style={{ fontSize: 13, color: '#888', marginTop: 4 }}>Connectez-vous à votre espace</div>
        </div>

        {error && (
          <div style={{ background: '#FCEBEB', color: '#A32D2D', padding: '10px 14px', borderRadius: 8, marginBottom: 16, fontSize: 13 }}>
            {error}
          </div>
        )}

        <div style={{ marginBottom: 14 }}>
          <label style={{ fontSize: 12, color: '#888', display: 'block', marginBottom: 5 }}>Email</label>
          <input
            type="email"
            value={form.email}
            onChange={e => setForm({ ...form, email: e.target.value })}
            placeholder="votre@email.com"
            onKeyDown={e => e.key === 'Enter' && submit()}
            style={{ width: '100%', padding: '9px 12px', border: '0.5px solid #ccc', borderRadius: 8, fontSize: 13, boxSizing: 'border-box' }}
          />
        </div>

        <div style={{ marginBottom: 24 }}>
          <label style={{ fontSize: 12, color: '#888', display: 'block', marginBottom: 5 }}>Mot de passe</label>
          <input
            type="password"
            value={form.password}
            onChange={e => setForm({ ...form, password: e.target.value })}
            placeholder="••••••••"
            onKeyDown={e => e.key === 'Enter' && submit()}
            style={{ width: '100%', padding: '9px 12px', border: '0.5px solid #ccc', borderRadius: 8, fontSize: 13, boxSizing: 'border-box' }}
          />
        </div>

        <button
          onClick={submit}
          disabled={loading}
          style={{
            width: '100%', padding: '10px', background: '#1D9E75',
            color: '#fff', border: 'none', borderRadius: 8,
            fontSize: 14, fontWeight: 500, cursor: 'pointer'
          }}
        >
          {loading ? 'Connexion...' : 'Se connecter'}
        </button>

        <div style={{ marginTop: 20, padding: '12px', background: '#f5f5f3', borderRadius: 8, fontSize: 12, color: '#888' }}>
          <strong>Compte de test :</strong><br />
          Email : jp.mbarga@douala-express.cm<br />
          Mot de passe : Test1234!
        </div>
      </div>
    </div>
  );
}
