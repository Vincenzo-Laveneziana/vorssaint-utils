// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MenuBarHidingStrings {
    let title: String
    let caption: String
    let autoCollapseTitle: String
    let autoCollapseCaption: String
}

extension FeatureStrings {
    static func menuBarHiding(_ language: AppLanguage) -> MenuBarHidingStrings {
        switch language {
        case .it:
            return .init(title: "Nascondi icone della barra dei menu",
                         caption: "Su macOS 27 la freccia è il confine: tieni premuto ⌘ e trascina le icone oltre la freccia. Richiede il permesso Accessibilità.",
                         autoCollapseTitle: "Nascondi di nuovo automaticamente",
                         autoCollapseCaption: "Nasconde le icone dopo il ritardo scelto, appena il puntatore lascia la barra dei menu.")
        case .enUS:
            return .init(title: "Hide menu bar icons",
                         caption: "On macOS 27 the arrow is the boundary. Command-drag icons across it to choose what stays visible. Accessibility permission is required.",
                         autoCollapseTitle: "Hide again automatically",
                         autoCollapseCaption: "Hides the icons after the selected delay, as soon as the pointer leaves the menu bar.")
        case .ptBR:
            return .init(title: "Ocultar ícones da barra de menus",
                         caption: "Adiciona uma seta e um separador. Arraste o separador com ⌘ para separar os ícones visíveis dos que quer ocultar.",
                         autoCollapseTitle: "Ocultar novamente automaticamente",
                         autoCollapseCaption: "Oculta os ícones após o intervalo escolhido, assim que o ponteiro sair da barra de menus.")
        case .es:
            return .init(title: "Ocultar iconos de la barra de menús",
                         caption: "Añade una flecha y un separador. Arrastra el separador con ⌘ entre los iconos que quieres mostrar y los que quieres ocultar.",
                         autoCollapseTitle: "Volver a ocultar automáticamente",
                         autoCollapseCaption: "Oculta los iconos tras el intervalo elegido, cuando el puntero sale de la barra de menús.")
        case .fr:
            return .init(title: "Masquer les icônes de la barre des menus",
                         caption: "Ajoute une flèche et un séparateur. Faites glisser le séparateur avec ⌘ entre les icônes à afficher et celles à masquer.",
                         autoCollapseTitle: "Masquer à nouveau automatiquement",
                         autoCollapseCaption: "Masque les icônes après le délai choisi, dès que le pointeur quitte la barre des menus.")
        case .de:
            return .init(title: "Menüleistensymbole ausblenden",
                         caption: "Fügt einen Pfeil und eine Trennlinie hinzu. Ziehe die Trennlinie mit ⌘ zwischen die Symbole, die sichtbar bleiben oder ausgeblendet werden sollen.",
                         autoCollapseTitle: "Automatisch wieder ausblenden",
                         autoCollapseCaption: "Blendet die Symbole nach der gewählten Zeit aus, sobald der Zeiger die Menüleiste verlässt.")
        case .tr:
            return .init(title: "Menü çubuğu simgelerini gizle",
                         caption: "Bir ok ve ayırıcı ekler. Ayırıcıyı ⌘ ile sürükleyerek görünür kalmasını ve gizlenmesini istediğiniz simgeleri ayırın.",
                         autoCollapseTitle: "Otomatik olarak yeniden gizle",
                         autoCollapseCaption: "İşaretçi menü çubuğundan ayrılınca simgeleri seçilen süre sonunda gizler.")
        case .ru:
            return .init(title: "Скрывать значки строки меню",
                         caption: "Добавляет стрелку и разделитель. Перетащите разделитель с ⌘ между значками, которые должны оставаться видимыми и скрываться.",
                         autoCollapseTitle: "Скрывать снова автоматически",
                         autoCollapseCaption: "Скрывает значки через выбранное время после того, как указатель покинет строку меню.")
        case .sk:
            return .init(title: "Skryť ikony na lište s ponukami",
                         caption: "Pridá šípku a oddeľovač. Potiahnutím oddeľovača s ⌘ rozdeľte ikony, ktoré majú zostať viditeľné a skryté.",
                         autoCollapseTitle: "Automaticky znova skryť",
                         autoCollapseCaption: "Skryje ikony po uplynutí zvoleného času, keď ukazovateľ opustí lištu s ponukami.")
        case .uk:
            return .init(title: "Приховати значки смуги меню",
                         caption: "Додає стрілку й роздільник. Перетягніть роздільник із ⌘ між значками, які мають залишатися видимими та приховуватися.",
                         autoCollapseTitle: "Автоматично приховувати знову",
                         autoCollapseCaption: "Ховає значки через вибраний час, щойно вказівник залишає смугу меню.")
        case .ja:
            return .init(title: "メニューバーのアイコンを隠す",
                         caption: "矢印と区切りを追加します。⌘キーを押しながら区切りをドラッグし、表示するアイコンと隠すアイコンの間に置きます。",
                         autoCollapseTitle: "自動的に再び隠す",
                         autoCollapseCaption: "ポインタがメニューバーを離れると、選択した時間の後にアイコンを隠します。")
        case .ko:
            return .init(title: "메뉴 막대 아이콘 숨기기",
                         caption: "화살표와 구분선을 추가합니다. ⌘을 누른 채 구분선을 드래그해 표시할 아이콘과 숨길 아이콘 사이에 놓으세요.",
                         autoCollapseTitle: "자동으로 다시 숨기기",
                         autoCollapseCaption: "포인터가 메뉴 막대를 벗어나면 선택한 시간이 지난 뒤 아이콘을 숨깁니다.")
        case .zhHans:
            return .init(title: "隐藏菜单栏图标",
                         caption: "添加箭头和分隔符。按住 ⌘ 拖动分隔符，将其放在要显示和要隐藏的图标之间。",
                         autoCollapseTitle: "自动再次隐藏",
                         autoCollapseCaption: "指针离开菜单栏并经过所选时间后隐藏图标。")
        case .zhTW:
            return .init(title: "隱藏選單列圖示",
                         caption: "加入箭頭和分隔線。按住 ⌘ 拖曳分隔線，將其放在要顯示和要隱藏的圖示之間。",
                         autoCollapseTitle: "自動再次隱藏",
                         autoCollapseCaption: "指標離開選單列並經過所選時間後隱藏圖示。")
        case .zhHK:
            return .init(title: "隱藏選單列圖示",
                         caption: "加入箭嘴和分隔線。按住 ⌘ 拖曳分隔線，將其放在要顯示和要隱藏的圖示之間。",
                         autoCollapseTitle: "自動再次隱藏",
                         autoCollapseCaption: "指標離開選單列並經過所選時間後隱藏圖示。")
        }
    }
}
