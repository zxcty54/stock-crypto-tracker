/// Bihar's 38 districts plus practical town/block suggestions for the first
/// launch. The free-text fallbacks keep smaller towns and villages searchable
/// while the official local directory grows.
abstract final class BiharLocations {
  static const districts = <String>[
    'Araria',
    'Arwal',
    'Aurangabad',
    'Banka',
    'Begusarai',
    'Bhagalpur',
    'Bhojpur',
    'Buxar',
    'Darbhanga',
    'East Champaran',
    'Gaya',
    'Gopalganj',
    'Jamui',
    'Jehanabad',
    'Kaimur (Bhabua)',
    'Katihar',
    'Khagaria',
    'Kishanganj',
    'Lakhisarai',
    'Madhepura',
    'Madhubani',
    'Munger',
    'Muzaffarpur',
    'Nalanda',
    'Nawada',
    'Patna',
    'Purnia',
    'Rohtas',
    'Saharsa',
    'Samastipur',
    'Saran',
    'Sheikhpura',
    'Sheohar',
    'Sitamarhi',
    'Siwan',
    'Supaul',
    'Vaishali',
    'West Champaran',
  ];

  static const Map<String, List<String>> _towns = <String, List<String>>{
    'Araria': <String>['Araria', 'Forbesganj', 'Jokihat'],
    'Arwal': <String>['Arwal', 'Karpi'],
    'Aurangabad': <String>['Aurangabad', 'Daudnagar'],
    'Banka': <String>['Banka', 'Amarpur'],
    'Begusarai': <String>['Begusarai', 'Barauni', 'Teghra'],
    'Bhagalpur': <String>['Bhagalpur', 'Naugachia'],
    'Bhojpur': <String>['Ara', 'Jagdishpur', 'Piro'],
    'Buxar': <String>['Buxar', 'Dumraon'],
    'Darbhanga': <String>['Darbhanga', 'Laheriasarai', 'Benipur'],
    'East Champaran': <String>['Motihari', 'Raxaul', 'Chakia'],
    'Gaya': <String>['Gaya', 'Bodh Gaya', 'Sherghati', 'Tekari'],
    'Gopalganj': <String>['Gopalganj', 'Hathua'],
    'Jamui': <String>['Jamui', 'Jhajha'],
    'Jehanabad': <String>['Jehanabad', 'Makhdumpur'],
    'Kaimur (Bhabua)': <String>['Bhabua', 'Mohania'],
    'Katihar': <String>['Katihar', 'Barsoi', 'Manihari'],
    'Khagaria': <String>['Khagaria', 'Gogri'],
    'Kishanganj': <String>['Kishanganj', 'Bahadurganj'],
    'Lakhisarai': <String>['Lakhisarai', 'Suryagarha'],
    'Madhepura': <String>['Madhepura', 'Udakishunganj'],
    'Madhubani': <String>['Madhubani', 'Jhanjharpur', 'Jainagar'],
    'Munger': <String>['Munger', 'Jamalpur'],
    'Muzaffarpur': <String>['Muzaffarpur', 'Kanti', 'Motipur'],
    'Nalanda': <String>['Bihar Sharif', 'Rajgir', 'Hilsa'],
    'Nawada': <String>['Nawada', 'Hisua'],
    'Patna': <String>[
      'Patna',
      'Danapur',
      'Phulwari Sharif',
      'Bihta',
      'Fatuha',
      'Barh',
    ],
    'Purnia': <String>['Purnia', 'Banmankhi'],
    'Rohtas': <String>['Sasaram', 'Dehri-on-Sone', 'Bikramganj'],
    'Saharsa': <String>['Saharsa', 'Simri Bakhtiarpur'],
    'Samastipur': <String>['Samastipur', 'Dalsinghsarai', 'Rosera'],
    'Saran': <String>['Chhapra', 'Marhaura', 'Sonpur'],
    'Sheikhpura': <String>['Sheikhpura', 'Barbigha'],
    'Sheohar': <String>['Sheohar'],
    'Sitamarhi': <String>['Sitamarhi', 'Belsand'],
    'Siwan': <String>['Siwan', 'Maharajganj'],
    'Supaul': <String>['Supaul', 'Birpur', 'Triveniganj'],
    'Vaishali': <String>['Hajipur', 'Mahua', 'Lalganj'],
    'West Champaran': <String>['Bettiah', 'Bagaha', 'Narkatiaganj'],
  };

  static const Map<String, List<String>> _blocks = <String, List<String>>{
    'Araria': <String>['Araria', 'Forbesganj', 'Jokihat', 'Raniganj'],
    'Begusarai': <String>['Begusarai', 'Barauni', 'Teghra', 'Bachhwara'],
    'Bhagalpur': <String>['Jagdishpur', 'Naugachia', 'Sabour', 'Sultanganj'],
    'Darbhanga': <String>['Darbhanga Sadar', 'Bahadurpur', 'Benipur', 'Jale'],
    'East Champaran': <String>['Motihari', 'Raxaul', 'Chakia', 'Areraj'],
    'Gaya': <String>['Gaya Sadar', 'Bodh Gaya', 'Manpur', 'Sherghati'],
    'Muzaffarpur': <String>['Musahari', 'Kanti', 'Motipur', 'Sakra'],
    'Nalanda': <String>['Bihar Sharif', 'Rajgir', 'Hilsa', 'Harnaut'],
    'Patna': <String>[
      'Patna Sadar',
      'Danapur',
      'Phulwari Sharif',
      'Bihta',
      'Sampatchak',
      'Fatuha',
      'Naubatpur',
    ],
    'Purnia': <String>['Purnia East', 'Banmankhi', 'Dhamdaha', 'Kasba'],
    'Rohtas': <String>['Sasaram', 'Dehri', 'Bikramganj', 'Nokha'],
    'Saharsa': <String>['Saharsa Sadar', 'Simri Bakhtiarpur', 'Salkhua'],
    'Samastipur': <String>['Samastipur', 'Dalsinghsarai', 'Rosera', 'Patori'],
    'Saran': <String>['Chhapra Sadar', 'Sonpur', 'Marhaura', 'Revelganj'],
    'Vaishali': <String>['Hajipur', 'Mahua', 'Lalganj', 'Raghopur'],
    'West Champaran': <String>['Bettiah', 'Bagaha', 'Narkatiaganj', 'Lauriya'],
  };

  static List<String> townsFor(String? district) {
    if (district == null) return const <String>[];
    return _towns[district] ?? <String>[district];
  }

  static List<String> blocksFor(String? district) {
    if (district == null) return const <String>[];
    return _blocks[district] ?? const <String>[];
  }

  static List<String> allTownNames() {
    return _towns.values.expand((towns) => towns).toSet().toList()..sort();
  }

  static List<String> allBlockNames() {
    return _blocks.values.expand((blocks) => blocks).toSet().toList()..sort();
  }
}
