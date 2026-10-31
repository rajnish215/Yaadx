import { initializeApp } from "firebase/app";
import {
  getAuth,
  setPersistence,
  browserSessionPersistence,
} from "firebase/auth";
// Public Firebase client configuration. Server credentials never belong here.
const app = initializeApp({
  apiKey: "AIzaSyBpkJFerZxEioQRGH2Cm6ZenizWFxOdDZY",
  appId: "1:537254223214:web:fe4e11d08bd1a182fd757f",
  messagingSenderId: "537254223214",
  projectId: "yaadx-8e018",
  authDomain: "yaadx-8e018.firebaseapp.com",
});
export const auth = getAuth(app);
export const persistenceReady = setPersistence(auth, browserSessionPersistence);
