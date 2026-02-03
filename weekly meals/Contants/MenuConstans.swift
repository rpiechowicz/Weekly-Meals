struct MenuConstans {
    struct Calendar: MenuModel {
        static let name: String = "Kalendarz"
        static let icon: String = "calendar"
    }
    
    struct Recipes: MenuModel {
        static let name: String = "Przepisy"
        static let icon: String = "book.pages"
    }
    
    struct Products: MenuModel {
        static let name: String = "Produkty"
        static let icon: String = "basket.fill"
    }
    
    struct Settings: MenuModel {
        static let name: String = "Ustawienia"
        static let icon: String = "gearshape"
    }
}
