export type AppRouteName =
  'home' |
  'identificationResult' |
  'audio' |
  'observationEditor' |
  'observationDetail' |
  'observations' |
  'map' |
  'stats' |
  'birdDetail' |
  'speciesPicker' |
  'publish' |
  'postDetail' |
  'journalEditor' |
  'shop' |
  'migration' |
  'profileEdit' |
  'settings' |
  'product' |
  'notifications';

export class AppRoute {
  readonly name: AppRouteName;
  readonly observationId: string;
  readonly speciesId: string;
  readonly postId: string;
  readonly bookId: string;
  readonly returnRouteName: AppRouteName;

  private constructor(
    name: AppRouteName,
    observationId: string = '',
    speciesId: string = '',
    postId: string = '',
    bookId: string = '',
    returnRouteName: AppRouteName = 'home'
  ) {
    this.name = name;
    this.observationId = observationId;
    this.speciesId = speciesId;
    this.postId = postId;
    this.bookId = bookId;
    this.returnRouteName = returnRouteName;
  }

  static home(): AppRoute { return new AppRoute('home'); }
  static identificationResult(speciesId: string): AppRoute { return new AppRoute('identificationResult', '', speciesId); }
  static audio(): AppRoute { return new AppRoute('audio'); }
  static observationEditor(observationId: string = '', speciesId: string = ''): AppRoute { return new AppRoute('observationEditor', observationId, speciesId); }
  static observationDetail(observationId: string): AppRoute { return new AppRoute('observationDetail', observationId); }
  static observations(): AppRoute { return new AppRoute('observations'); }
  static map(): AppRoute { return new AppRoute('map'); }
  static stats(): AppRoute { return new AppRoute('stats'); }
  static birdDetail(speciesId: string): AppRoute { return new AppRoute('birdDetail', '', speciesId); }
  static speciesPicker(returnRoute: AppRoute): AppRoute { return new AppRoute('speciesPicker', returnRoute.observationId, returnRoute.speciesId, returnRoute.postId, returnRoute.bookId, returnRoute.name); }
  static publish(speciesId: string = ''): AppRoute { return new AppRoute('publish', '', speciesId); }
  static postDetail(postId: string): AppRoute { return new AppRoute('postDetail', '', '', postId); }
  static journalEditor(bookId: string): AppRoute { return new AppRoute('journalEditor', '', '', '', bookId); }
  static shop(): AppRoute { return new AppRoute('shop'); }
  static migration(): AppRoute { return new AppRoute('migration'); }
  static profileEdit(): AppRoute { return new AppRoute('profileEdit'); }
  static settings(): AppRoute { return new AppRoute('settings'); }
  static product(): AppRoute { return new AppRoute('product'); }
  static notifications(): AppRoute { return new AppRoute('notifications'); }
  returnRoute(): AppRoute { return new AppRoute(this.returnRouteName, this.observationId, this.speciesId, this.postId, this.bookId); }
}
