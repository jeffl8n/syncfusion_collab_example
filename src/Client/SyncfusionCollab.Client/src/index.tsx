import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import './App.css';
import App from './App';
import reportWebVitals from './reportWebVitals';

import { registerLicense } from '@syncfusion/ej2-base';

const syncfusionLicenseKey = process.env.REACT_APP_SYNCFUSION_LICENSE_KEY;

if (!syncfusionLicenseKey) {
  // Log once during startup so missing secrets are obvious in development
  console.warn('Syncfusion license key is not configured. Set REACT_APP_SYNCFUSION_LICENSE_KEY before building.');
} else {
  registerLicense(syncfusionLicenseKey);
}

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
 // <React.StrictMode>
    <App />
  //</React.StrictMode>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
