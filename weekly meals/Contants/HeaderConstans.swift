struct HeaderConstans {
    struct Calendar: IHeaderConfiguration {
        static let title: String = "Kalendarz"
        static let subtitle: String = "Zaplanuj swoje posiłki na cały tydzień"
    }
    
    struct Recipes: IHeaderConfiguration {
        static let title: String = "Przepisy"
        static let subtitle: String = "Odkryj pyszne przepisy i twórz własne"
    }
    
    struct Products: IHeaderConfiguration {
        static let title: String = "Produkty"
        static let subtitle: String = "Zarządzaj swoją listą zakupów"
    }
    
    struct Settings: IHeaderConfiguration {
        static let title: String = "Ustawienia"
        static let subtitle: String = "Dostosuj aplikację do swoich potrzeb"
    }
}
