.pragma library

// Paletas modulares para o Theme.qml.
// Para adicionar um novo tema, basta inserir um objeto em ALL (e o nome do grupo em GROUPS, se for novo).
// Roles de `c`: [bg, s1, s2, s3, mute, grey, fg]
//   bg   — fundo da tela / wallpaper
//   s1   — barra, painéis, fundo do kitty
//   s2   — blocos / tiles, controles desligados
//   s3   — linhas, bordas inativas, seleção
//   mute — elementos desativados
//   grey — rótulos, texto secundário
//   fg   — texto principal, elementos ativos, foco
//   accent — cor de destaque
//   red    — alertas críticos / erro

const DEFAULT_ANSI_DARK = [
    "#0E0E0E", "#D71921", "#9BB59A", "#D9C38A", "#8EA3C2", "#B79BC2", "#8FB8B8", "#C9C9C9",
    "#4A4A4A", "#F0434B", "#B5CCB4", "#E8D6A8", "#AABBD4", "#CDB6D6", "#ABCDCD", "#F2F2F2"
];

const DEFAULT_ANSI_LIGHT = [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => DEFAULT_ANSI_DARK[i]);

const ALL = [
    { id: "default", name: "dark", group: "default", light: false,
      c: ["#000000", "#0E0E0E", "#1A1A1A", "#2A2A2A", "#4A4A4A", "#8C8C8C", "#F2F2F2"], accent: "#D71921", red: "#D71921",
      ansi: DEFAULT_ANSI_DARK },
    { id: "default-light", name: "light", group: "default", light: true,
      c: ["#E9E9E9", "#FFFFFF", "#F1F1F1", "#D9D9D9", "#B8B8B8", "#6E6E6E", "#0B0B0B"], accent: "#D71921", red: "#D71921",
      ansi: DEFAULT_ANSI_LIGHT },

    { id: "mocha", name: "mocha", group: "catppuccin", light: false,
      c: ["#181825", "#1E1E2E", "#313244", "#45475A", "#585B70", "#7F849C", "#CDD6F4"], accent: "#CBA6F7", red: "#F38BA8",
      ansi: ["#45475A", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#BAC2DE", "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#A6ADC8"] },
    { id: "macchiato", name: "macchiato", group: "catppuccin", light: false,
      c: ["#1E2030", "#24273A", "#363A4F", "#494D64", "#5B6078", "#8087A2", "#CAD3F5"], accent: "#C6A0F6", red: "#ED8796",
      ansi: ["#494D64", "#ED8796", "#A6DA95", "#EED49F", "#8AADF4", "#F5BDE6", "#8BD5CA", "#B8C0E0", "#5B6078", "#ED8796", "#A6DA95", "#EED49F", "#8AADF4", "#F5BDE6", "#8BD5CA", "#A5ADCB"] },
    { id: "frappe", name: "frappé", group: "catppuccin", light: false,
      c: ["#292C3C", "#303446", "#414559", "#51576D", "#626880", "#838BA7", "#C6D0F5"], accent: "#CA9EE6", red: "#E78284",
      ansi: ["#51576D", "#E78284", "#A6D189", "#E5C890", "#8CAAEE", "#F4B8E4", "#81C8BE", "#B5BFE2", "#626880", "#E78284", "#A6D189", "#E5C890", "#8CAAEE", "#F4B8E4", "#81C8BE", "#A5ADCE"] },
    { id: "latte", name: "latte", group: "catppuccin", light: true,
      c: ["#DCE0E8", "#EFF1F5", "#E6E9EF", "#CCD0DA", "#ACB0BE", "#6C6F85", "#4C4F69"], accent: "#8839EF", red: "#D20F39",
      ansi: ["#5C5F77", "#D20F39", "#40A02B", "#DF8E1D", "#1E66F5", "#EA76CB", "#179299", "#ACB0BE", "#6C6F85", "#D20F39", "#40A02B", "#DF8E1D", "#1E66F5", "#EA76CB", "#179299", "#BCC0CC"] },

    { id: "rosepine", name: "main", group: "rosé pine", light: false,
      c: ["#191724", "#1F1D2E", "#26233A", "#403D52", "#524F67", "#908CAA", "#E0DEF4"], accent: "#EBBCBA", red: "#EB6F92",
      ansi: ["#26233A", "#EB6F92", "#31748F", "#F6C177", "#9CCFD8", "#C4A7E7", "#EBBCBA", "#E0DEF4", "#6E6A86", "#EB6F92", "#31748F", "#F6C177", "#9CCFD8", "#C4A7E7", "#EBBCBA", "#E0DEF4"] },
    { id: "rosepine-moon", name: "moon", group: "rosé pine", light: false,
      c: ["#232136", "#2A273F", "#393552", "#44415A", "#56526E", "#908CAA", "#E0DEF4"], accent: "#EA9A97", red: "#EB6F92",
      ansi: ["#393552", "#EB6F92", "#3E8FB0", "#F6C177", "#9CCFD8", "#C4A7E7", "#EA9A97", "#E0DEF4", "#6E6A86", "#EB6F92", "#3E8FB0", "#F6C177", "#9CCFD8", "#C4A7E7", "#EA9A97", "#E0DEF4"] },
    { id: "rosepine-dawn", name: "dawn", group: "rosé pine", light: true,
      c: ["#F2E9E1", "#FFFAF3", "#FAF4ED", "#DFDAD9", "#CECACD", "#797593", "#575279"], accent: "#D7827E", red: "#B4637A",
      ansi: ["#F2E9E1", "#B4637A", "#286983", "#EA9D34", "#56949F", "#907AA9", "#D7827E", "#575279", "#9893A5", "#B4637A", "#286983", "#EA9D34", "#56949F", "#907AA9", "#D7827E", "#575279"] },

    { id: "gruvbox", name: "dark", group: "gruvbox", light: false,
      c: ["#1D2021", "#282828", "#3C3836", "#504945", "#665C54", "#928374", "#EBDBB2"], accent: "#FE8019", red: "#FB4934",
      ansi: ["#3C3836", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#A89984", "#928374", "#FB4934", "#B8BB26", "#FABD2F", "#83A598", "#D3869B", "#8EC07C", "#FBF1C7"] },
    { id: "gruvbox-light", name: "light", group: "gruvbox", light: true,
      c: ["#EBDBB2", "#FBF1C7", "#F2E5BC", "#D5C4A1", "#BDAE93", "#7C6F64", "#3C3836"], accent: "#AF3A03", red: "#9D0006",
      ansi: ["#EBDBB2", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#7C6F64", "#928374", "#9D0006", "#79740E", "#B57614", "#076678", "#8F3F71", "#427B58", "#282828"] },

    { id: "nord", name: "nord", group: "more", light: false,
      c: ["#242933", "#2E3440", "#3B4252", "#434C5E", "#4C566A", "#616E88", "#D8DEE9"], accent: "#88C0D0", red: "#BF616A",
      ansi: ["#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0", "#4C566A", "#BF616A", "#A3BE8C", "#D08770", "#5E81AC", "#B48EAD", "#8FBCBB", "#ECEFF4"] },
    { id: "dracula", name: "dracula", group: "more", light: false,
      c: ["#191A21", "#282A36", "#343746", "#44475A", "#505877", "#6272A4", "#F8F8F2"], accent: "#BD93F9", red: "#FF5555",
      ansi: ["#21222C", "#FF5555", "#50FA7B", "#F1FA8C", "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2", "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5", "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF"] },
    { id: "tokyonight", name: "tokyo night", group: "more", light: false,
      c: ["#16161E", "#1A1B26", "#292E42", "#3B4261", "#545C7E", "#737AA2", "#C0CAF5"], accent: "#7AA2F7", red: "#F7768E",
      ansi: ["#15161E", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#A9B1D6", "#414868", "#FF899D", "#9FE044", "#FABA4A", "#8DB0FF", "#C7A9FF", "#A4DAFF", "#C0CAF5"] },
    { id: "everforest", name: "everforest", group: "more", light: false,
      c: ["#232A2E", "#2D353B", "#343F44", "#475258", "#56635F", "#859289", "#D3C6AA"], accent: "#A7C080", red: "#E67E80",
      ansi: ["#343F44", "#E67E80", "#A7C080", "#DBBC7F", "#7FBBB3", "#D699B6", "#83C092", "#859289", "#868D80", "#E67E80", "#A7C080", "#DBBC7F", "#7FBBB3", "#D699B6", "#83C092", "#9DA9A0"] },
    { id: "kanagawa", name: "kanagawa", group: "more", light: false,
      c: ["#16161D", "#1F1F28", "#2A2A37", "#363646", "#54546D", "#727169", "#DCD7BA"], accent: "#7E9CD8", red: "#E82424",
      ansi: ["#16161D", "#C34043", "#76946A", "#C0A36E", "#7E9CD8", "#957FB8", "#6A9589", "#C8C093", "#727169", "#E82424", "#98BB6C", "#E6C384", "#7FB4CA", "#938AA9", "#7AA89F", "#DCD7BA"] }
];

const GROUPS = ["default", "catppuccin", "rosé pine", "gruvbox", "more"];
