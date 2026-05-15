import axios from 'axios';

const api = axios.create({ baseURL: 'http://localhost:4000/api' });

api.interceptors.request.use(config => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  res => res,
  err => {
    if (err.response?.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/';
    }
    return Promise.reject(err);
  }
);

export const login           = (data)       => api.post('/auth/login', data);
export const getMe           = ()           => api.get('/auth/me');
export const getDashboard    = ()           => api.get('/dashboard');
export const getCommandes    = ()           => api.get('/commandes');
export const getCommande     = (id)         => api.get(`/commandes/${id}`);
export const createCommande  = (data)       => api.post('/commandes', data);
export const updateStatut    = (id, status) => api.patch(`/commandes/${id}/statut`, { status });
export const getProduits     = ()           => api.get('/produits');
export const createProduit   = (data)       => api.post('/produits', data);
export const updateProduit   = (id, data)   => api.patch(`/produits/${id}`, data);
export const getLivraisons   = ()           => api.get('/livraisons');
export const createLivraison = (data)       => api.post('/livraisons', data);
export const getStock        = ()           => api.get('/stock');
export const entreeStock     = (data)       => api.post('/stock/entree', data);

export default api;
