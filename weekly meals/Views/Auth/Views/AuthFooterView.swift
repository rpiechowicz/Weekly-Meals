import SwiftUI

struct AuthFooterView: View {
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Kontynuując, akceptujesz Warunki korzystania i potwierdzasz, że zapoznałeś(-aś) się z Polityką prywatności.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 16) {
                Button("Polityka prywatności") {
                    showPrivacyPolicy = true
                }
                .buttonStyle(.plain)
                .font(.footnote)

                Button("Warunki korzystania") {
                    showTermsOfService = true
                }
                .buttonStyle(.plain)
                .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalDocumentSheet(title: "Polityka prywatności") {
                PrivacyPolicyContent()
            }
        }
        .sheet(isPresented: $showTermsOfService) {
            LegalDocumentSheet(title: "Warunki korzystania") {
                TermsOfServiceContent()
            }
        }
    }
}

// MARK: - Reużywalny kontener sheeta

private struct LegalDocumentSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content()
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Wspólne bloki

private struct LegalSection<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.headline)
            content()
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

private struct LegalMeta: View {
    let effectiveDate: String
    let version: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Wersja \(version)")
            Text("Obowiązuje od: \(effectiveDate)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Polityka prywatności

private struct PrivacyPolicyContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalMeta(effectiveDate: "17 kwietnia 2026", version: "1.0")

            Text("Niniejsza Polityka prywatności opisuje, jakie dane osobowe są przetwarzane w związku z korzystaniem z aplikacji mobilnej Weekly Meals („Aplikacja”), na jakich podstawach prawnych, w jakich celach oraz jakie prawa przysługują użytkownikom. Dokument został przygotowany w zgodzie z Rozporządzeniem Parlamentu Europejskiego i Rady (UE) 2016/679 z dnia 27 kwietnia 2016 r. („RODO”) oraz ustawą z dnia 10 maja 2018 r. o ochronie danych osobowych.")

            LegalSection(number: 1, title: "Administrator danych") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Administratorem danych osobowych użytkowników Aplikacji jest Rafał Piechowicz („Administrator”).")
                    Text("Kontakt w sprawach dotyczących danych osobowych:")
                    Text("e-mail: piechowicz.rafal98@gmail.com")
                        .fontWeight(.medium)
                }
            }

            LegalSection(number: 2, title: "Zakres przetwarzanych danych") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Administrator przetwarza wyłącznie dane niezbędne do świadczenia usługi:")
                    Text("• stabilny identyfikator użytkownika Apple (tzw. sub) — otrzymywany od Apple po zalogowaniu;")
                    Text("• adres e-mail — prawdziwy albo prywatny adres przekazujący Apple w formacie *@privaterelay.appleid.com, jeżeli użytkownik wybrał opcję „Ukryj mój e-mail”;")
                    Text("• imię i nazwisko — wyłącznie jeśli użytkownik udostępni je przy pierwszym logowaniu przez Apple;")
                    Text("• dane generowane w trakcie korzystania z Aplikacji (plany posiłków, listy zakupów, preferencje) — tworzone przez samego użytkownika;")
                    Text("• techniczne logi dostępu (znacznik czasu logowania, identyfikator tokenu sesji) — w celu bezpieczeństwa.")
                }
            }

            LegalSection(number: 3, title: "Cele i podstawy prawne przetwarzania") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Założenie i utrzymanie konta, świadczenie funkcji Aplikacji — art. 6 ust. 1 lit. b RODO (wykonanie umowy);")
                    Text("• Zapewnienie bezpieczeństwa Aplikacji, wykrywanie nadużyć, logi techniczne — art. 6 ust. 1 lit. f RODO (prawnie uzasadniony interes Administratora);")
                    Text("• Obsługa zgłoszeń i reklamacji — art. 6 ust. 1 lit. b i f RODO;")
                    Text("• Wypełnienie obowiązków prawnych (np. odpowiedzi na żądania organów) — art. 6 ust. 1 lit. c RODO.")
                }
            }

            LegalSection(number: 4, title: "Sign in with Apple") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Logowanie odbywa się wyłącznie za pomocą Sign in with Apple. Administrator nie otrzymuje hasła do konta Apple użytkownika.")
                    Text("Jeżeli użytkownik wybiera opcję „Ukryj mój e-mail”, Apple udostępnia Administratorowi unikalny adres przekazujący. Wiadomości wysyłane na ten adres są przekierowywane na prawdziwy adres użytkownika przez Apple. Administrator nie zna i nie próbuje odszyfrować prawdziwego adresu.")
                    Text("Imię i nazwisko są udostępniane przez Apple wyłącznie przy pierwszym logowaniu na dane urządzenie. W przypadku rezygnacji z ich udostępnienia użytkownik jest identyfikowany przez nazwę zastępczą.")
                }
            }

            LegalSection(number: 5, title: "Odbiorcy danych") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dane mogą być udostępniane wyłącznie:")
                    Text("• Apple Inc. — w zakresie koniecznym do weryfikacji tożsamości przez Sign in with Apple (Apple działa jako niezależny administrator swoich danych);")
                    Text("• dostawcom infrastruktury (hosting, baza danych) wyłącznie w zakresie koniecznym do utrzymania usługi, na podstawie umów powierzenia przetwarzania;")
                    Text("• uprawnionym organom państwowym, jeżeli obowiązek ich przekazania wynika z powszechnie obowiązujących przepisów prawa.")
                    Text("Dane nie są sprzedawane i nie są wykorzystywane w celach marketingowych podmiotów trzecich.")
                }
            }

            LegalSection(number: 6, title: "Przekazywanie danych do państw trzecich") {
                Text("Administrator nie przekazuje danych do państw trzecich (poza EOG) w sposób zamierzony. W przypadku, gdy wybrany dostawca infrastruktury lub Apple Inc. realizują przetwarzanie poza EOG, odbywa się to wyłącznie w oparciu o mechanizmy zapewniające odpowiedni poziom ochrony zgodny z rozdziałem V RODO (np. standardowe klauzule umowne).")
            }

            LegalSection(number: 7, title: "Okres przechowywania") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dane konta są przechowywane przez cały okres aktywnego korzystania z Aplikacji.")
                    Text("Po usunięciu konta dane osobowe są usuwane nie później niż w terminie 30 dni, z wyjątkiem tych, których przechowywanie jest wymagane przepisami prawa lub które są niezbędne do ustalenia, dochodzenia lub obrony roszczeń.")
                    Text("Logi techniczne są przechowywane nie dłużej niż 90 dni.")
                }
            }

            LegalSection(number: 8, title: "Prawa użytkownika") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zgodnie z RODO użytkownikowi przysługują prawa:")
                    Text("• dostępu do danych (art. 15);")
                    Text("• sprostowania danych (art. 16);")
                    Text("• usunięcia danych — „prawo do bycia zapomnianym” (art. 17);")
                    Text("• ograniczenia przetwarzania (art. 18);")
                    Text("• przenoszenia danych (art. 20);")
                    Text("• sprzeciwu wobec przetwarzania opartego na prawnie uzasadnionym interesie (art. 21).")
                    Text("W celu realizacji powyższych praw prosimy o kontakt pod adresem: piechowicz.rafal98@gmail.com.")
                    Text("Użytkownik ma również prawo wniesienia skargi do Prezesa Urzędu Ochrony Danych Osobowych (ul. Stawki 2, 00-193 Warszawa).")
                }
            }

            LegalSection(number: 9, title: "Usunięcie konta") {
                Text("Użytkownik może w każdej chwili zażądać usunięcia konta i powiązanych z nim danych osobowych, wysyłając wiadomość na adres piechowicz.rafal98@gmail.com z adresu e-mail powiązanego z kontem lub korzystając z funkcji usuwania konta w Aplikacji, jeżeli została udostępniona. Żądanie realizowane jest niezwłocznie, nie później niż w terminie 30 dni.")
            }

            LegalSection(number: 10, title: "Zautomatyzowane podejmowanie decyzji") {
                Text("Dane osobowe nie są wykorzystywane do zautomatyzowanego podejmowania decyzji wywołujących skutki prawne, w tym do profilowania w rozumieniu art. 22 RODO.")
            }

            LegalSection(number: 11, title: "Bezpieczeństwo danych") {
                Text("Administrator stosuje środki techniczne i organizacyjne odpowiednie do ryzyka — w szczególności szyfrowanie transmisji (HTTPS/TLS), przechowywanie tokenów sesji w Apple Keychain, stosowanie kryptograficznie bezpiecznych nonce'ów oraz weryfikację podpisu tokenów tożsamości Apple wobec oficjalnych kluczy publicznych Apple.")
            }

            LegalSection(number: 12, title: "Zmiany polityki") {
                Text("Administrator może zaktualizować niniejszą Politykę prywatności w związku ze zmianami prawa lub funkcjonalności Aplikacji. Istotne zmiany zostaną zakomunikowane w Aplikacji z odpowiednim wyprzedzeniem. Dalsze korzystanie z Aplikacji po wejściu w życie zmian oznacza zapoznanie się z nową wersją dokumentu.")
            }

            Text("W razie pytań dotyczących przetwarzania danych prosimy o kontakt: piechowicz.rafal98@gmail.com.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Warunki korzystania

private struct TermsOfServiceContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalMeta(effectiveDate: "17 kwietnia 2026", version: "1.0")

            Text("Niniejsze Warunki korzystania („Warunki”) określają zasady świadczenia usług drogą elektroniczną w aplikacji mobilnej Weekly Meals („Aplikacja”) oraz prawa i obowiązki użytkowników. Warunki stanowią regulamin w rozumieniu art. 8 ustawy z dnia 18 lipca 2002 r. o świadczeniu usług drogą elektroniczną.")

            LegalSection(number: 1, title: "Postanowienia ogólne") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Usługodawcą jest Rafał Piechowicz („Usługodawca”), kontakt: piechowicz.rafal98@gmail.com.")
                    Text("Użytkownikiem jest osoba fizyczna korzystająca z Aplikacji. Warunkiem korzystania z pełnej funkcjonalności Aplikacji jest zalogowanie się za pomocą Sign in with Apple.")
                    Text("Korzystanie z Aplikacji jest równoznaczne z akceptacją Warunków.")
                }
            }

            LegalSection(number: 2, title: "Wymagania techniczne") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Do korzystania z Aplikacji wymagane jest:")
                    Text("• urządzenie z systemem iOS w wersji obsługiwanej przez aktualne wydanie Aplikacji;")
                    Text("• aktywne konto Apple ID z włączonym uwierzytelnianiem dwuskładnikowym;")
                    Text("• dostęp do sieci Internet.")
                }
            }

            LegalSection(number: 3, title: "Konto użytkownika") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Konto zakładane jest automatycznie przy pierwszym logowaniu za pomocą Sign in with Apple.")
                    Text("Użytkownik jest zobowiązany do zachowania w poufności dostępu do swojego urządzenia i konta Apple. Usługodawca nie odpowiada za skutki udostępnienia urządzenia osobom trzecim.")
                    Text("Z jednego konta Apple może korzystać wyłącznie jeden użytkownik (osoba fizyczna).")
                }
            }

            LegalSection(number: 4, title: "Zakres i charakter usługi") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aplikacja umożliwia planowanie posiłków, tworzenie list zakupów oraz zarządzanie preferencjami żywieniowymi.")
                    Text("Propozycje posiłków oraz sugestie żywieniowe mają charakter wyłącznie informacyjny i nie zastępują porady lekarza, dietetyka ani specjalisty. Użytkownik powinien samodzielnie ocenić, czy dany plan jest dla niego odpowiedni, w szczególności biorąc pod uwagę alergie, nietolerancje pokarmowe i indywidualny stan zdrowia.")
                }
            }

            LegalSection(number: 5, title: "Zasady korzystania") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Użytkownik zobowiązuje się do korzystania z Aplikacji zgodnie z prawem, dobrymi obyczajami oraz niniejszymi Warunkami. Zabronione jest w szczególności:")
                    Text("• dostarczanie treści o charakterze bezprawnym, w tym naruszających dobra osobiste lub prawa własności intelektualnej osób trzecich;")
                    Text("• podejmowanie działań mających na celu zakłócenie funkcjonowania Aplikacji, w tym ataków DoS, prób uzyskania nieautoryzowanego dostępu, inżynierii wstecznej chronionych części systemu;")
                    Text("• tworzenie wielu kont w celu obejścia ograniczeń;")
                    Text("• używanie Aplikacji do działalności komercyjnej bez odrębnej zgody Usługodawcy.")
                }
            }

            LegalSection(number: 6, title: "Własność intelektualna") {
                Text("Wszelkie prawa własności intelektualnej do Aplikacji, w tym kodu źródłowego, grafik, logotypów i treści, przysługują Usługodawcy lub podmiotom, z których licencji korzysta Usługodawca. Użytkownik otrzymuje niewyłączną, nieprzenoszalną, odwołalną licencję na korzystanie z Aplikacji na własnym urządzeniu w zakresie jej przeznaczenia. Treści utworzone przez użytkownika (plany, listy, preferencje) pozostają jego własnością.")
            }

            LegalSection(number: 7, title: "Odpowiedzialność") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Usługodawca dokłada należytej staranności, aby Aplikacja działała prawidłowo. Usługodawca nie gwarantuje jednak nieprzerwanej, wolnej od błędów dostępności Aplikacji, w szczególności w przypadku siły wyższej, awarii sieci operatorów telekomunikacyjnych lub usług Apple.")
                    Text("Usługodawca nie odpowiada za szkody wynikłe z nieprawidłowego korzystania z Aplikacji, decyzji żywieniowych podjętych przez użytkownika na podstawie propozycji Aplikacji ani z utraty danych spowodowanej działaniem użytkownika lub osób trzecich.")
                    Text("Odpowiedzialność wobec konsumentów nie jest wyłączona ani ograniczona w zakresie, w jakim przepisy bezwzględnie obowiązujące na to nie pozwalają.")
                }
            }

            LegalSection(number: 8, title: "Reklamacje") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reklamacje dotyczące Aplikacji można składać na adres: piechowicz.rafal98@gmail.com.")
                    Text("Reklamacja powinna zawierać imię, adres e-mail, opis problemu oraz oczekiwany sposób rozpatrzenia.")
                    Text("Usługodawca rozpatruje reklamacje w terminie 14 dni od ich otrzymania, informując o wyniku drogą elektroniczną.")
                }
            }

            LegalSection(number: 9, title: "Rozwiązanie umowy i usunięcie konta") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Użytkownik może w każdej chwili zakończyć korzystanie z Aplikacji i zażądać usunięcia konta zgodnie z procedurą opisaną w Polityce prywatności.")
                    Text("Usługodawca może zablokować lub usunąć konto użytkownika w przypadku rażącego naruszenia Warunków, po uprzednim bezskutecznym wezwaniu do zaprzestania naruszeń, z wyjątkiem przypadków, w których natychmiastowa reakcja jest konieczna ze względu na bezpieczeństwo innych użytkowników lub Aplikacji.")
                }
            }

            LegalSection(number: 10, title: "Odstąpienie od umowy") {
                Text("Konsumentowi w rozumieniu art. 22(1) Kodeksu cywilnego przysługuje prawo odstąpienia od umowy o świadczenie usług drogą elektroniczną w terminie 14 dni od dnia jej zawarcia, bez podania przyczyny. Oświadczenie o odstąpieniu można złożyć w dowolnej formie, w szczególności drogą elektroniczną na adres piechowicz.rafal98@gmail.com. Prawo odstąpienia nie przysługuje, jeżeli świadczenie usługi zostało w pełni wykonane za wyraźną zgodą konsumenta, który został poinformowany o utracie tego prawa.")
            }

            LegalSection(number: 11, title: "Zmiany Warunków") {
                Text("Usługodawca może zmienić Warunki z ważnych powodów (zmiana prawa, zmiana zakresu lub charakteru usługi, względy bezpieczeństwa). O zmianach użytkownicy zostaną poinformowani w Aplikacji z co najmniej 14-dniowym wyprzedzeniem. Brak akceptacji zmian uprawnia użytkownika do rozwiązania umowy i usunięcia konta.")
            }

            LegalSection(number: 12, title: "Prawo właściwe i spory") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("W sprawach nieuregulowanych Warunkami zastosowanie mają przepisy prawa polskiego.")
                    Text("Sądem właściwym do rozstrzygania sporów jest sąd właściwy miejscowo dla Usługodawcy, z zastrzeżeniem bezwzględnie obowiązujących przepisów dotyczących konsumentów.")
                    Text("Konsument może skorzystać z pozasądowych sposobów rozpatrywania reklamacji i dochodzenia roszczeń, w szczególności za pośrednictwem platformy ODR Komisji Europejskiej dostępnej pod adresem: https://ec.europa.eu/consumers/odr/.")
                }
            }

            LegalSection(number: 13, title: "Kontakt") {
                Text("Pytania dotyczące Warunków prosimy kierować na adres: piechowicz.rafal98@gmail.com.")
            }
        }
    }
}

#Preview("Footer") {
    AuthFooterView()
        .padding()
}

#Preview("Privacy Policy") {
    LegalDocumentSheet(title: "Polityka prywatności") {
        PrivacyPolicyContent()
    }
}

#Preview("Terms of Service") {
    LegalDocumentSheet(title: "Warunki korzystania") {
        TermsOfServiceContent()
    }
}
