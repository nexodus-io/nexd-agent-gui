export class SharedState {
  private _globalAuthUrl: string | null = null;

  get globalAuthUrl() {
    return this._globalAuthUrl;
  }

  setGlobalAuthUrl(url: string | null) {
    this._globalAuthUrl = url;
  }
}

const sharedState = new SharedState();

export default sharedState;
