import { Developer, App } from '../models';

declare global {
  namespace Express {
    interface Request {
      developer?: Developer;
      app?: App;
    }
  }
}

export {};
