struct MenuConstans {
    struct Calendar: IMenuConfiguration {
        static let name: String = "Kalendarz"
        static let icon: String = "calendar"
    }
    
    struct Recipes: IMenuConfiguration {
        static let name: String = "Przepisy"
        static let icon: String = "book.pages"
    }
    
    struct Products: IMenuConfiguration {
        static let name: String = "Produkty"
        static let icon: String = "basket.fill"
    }
    
    struct Settings: IMenuConfiguration {
        static let name: String = "Ustawienia"
        static let icon: String = "gearshape"
    }
}
