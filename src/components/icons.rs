use dioxus::prelude::*;

#[component]
pub fn BrandGlyph() -> Element {
    rsx! {
        svg {
            width: "22",
            height: "22",
            view_box: "0 0 24 24",
            fill: "none",
            stroke: "currentColor",
            stroke_width: "2.2",
            stroke_linecap: "round",
            stroke_linejoin: "round",
            "aria-hidden": "true",
            circle { cx: "11", cy: "11", r: "7" }
            path { d: "M16 16l4 4" }
        }
    }
}

#[component]
pub fn Icon(name: &'static str, #[props(default = 20)] size: u32) -> Element {
    let s = format!("{size}");
    rsx! {
        svg {
            width: "{s}",
            height: "{s}",
            view_box: "0 0 24 24",
            fill: "none",
            stroke: "currentColor",
            stroke_width: "1.9",
            stroke_linecap: "round",
            stroke_linejoin: "round",
            "aria-hidden": "true",
            match name {
                "chat" => rsx! {
                    path { d: "M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z" }
                },
                "contacts" => rsx! {
                    path { d: "M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" }
                    circle { cx: "9", cy: "7", r: "4" }
                    path { d: "M23 21v-2a4 4 0 0 0-3-3.87" }
                    path { d: "M16 3.13a4 4 0 0 1 0 7.75" }
                },
                "requests" => rsx! {
                    path { d: "M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" }
                    circle { cx: "8.5", cy: "7", r: "4" }
                    line { x1: "20", y1: "8", x2: "20", y2: "14" }
                    line { x1: "23", y1: "11", x2: "17", y2: "11" }
                },
                "profile" => rsx! {
                    path { d: "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" }
                    circle { cx: "12", cy: "7", r: "4" }
                },
                "back" => rsx! {
                    polyline { points: "15 18 9 12 15 6" }
                },
                "send" => rsx! {
                    line { x1: "22", y1: "2", x2: "11", y2: "13" }
                    polygon { points: "22 2 15 22 11 13 2 9 22 2" }
                },
                "plus" => rsx! {
                    line { x1: "12", y1: "5", x2: "12", y2: "19" }
                    line { x1: "5", y1: "12", x2: "19", y2: "12" }
                },
                "link" => rsx! {
                    path { d: "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" }
                    path { d: "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" }
                },
                "info" => rsx! {
                    circle { cx: "12", cy: "12", r: "10" }
                    line { x1: "12", y1: "16", x2: "12", y2: "12" }
                    line { x1: "12", y1: "8", x2: "12.01", y2: "8" }
                },
                "trash" => rsx! {
                    polyline { points: "3 6 5 6 21 6" }
                    path { d: "M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" }
                    path { d: "M10 11v6" }
                    path { d: "M14 11v6" }
                },
                "refresh" => rsx! {
                    polyline { points: "23 4 23 10 17 10" }
                    polyline { points: "1 20 1 14 7 14" }
                    path { d: "M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" }
                },
                "download" => rsx! {
                    path { d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" }
                    polyline { points: "7 10 12 15 17 10" }
                    line { x1: "12", y1: "15", x2: "12", y2: "3" }
                },
                "shield" => rsx! {
                    path { d: "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" }
                },
                "server" => rsx! {
                    rect { x: "2", y: "3", width: "20", height: "8", rx: "2" }
                    rect { x: "2", y: "13", width: "20", height: "8", rx: "2" }
                },
                "attach" => rsx! {
                    path { d: "M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" }
                },
                "sun" => rsx! {
                    circle { cx: "12", cy: "12", r: "5" }
                    line { x1: "12", y1: "1", x2: "12", y2: "3" }
                    line { x1: "12", y1: "21", x2: "12", y2: "23" }
                    line { x1: "4.22", y1: "4.22", x2: "5.64", y2: "5.64" }
                    line { x1: "18.36", y1: "18.36", x2: "19.78", y2: "19.78" }
                    line { x1: "1", y1: "12", x2: "3", y2: "12" }
                    line { x1: "21", y1: "12", x2: "23", y2: "12" }
                },
                "moon" => rsx! {
                    path { d: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" }
                },
                "check" => rsx! {
                    polyline { points: "20 6 9 17 4 12" }
                },
                "close" => rsx! {
                    line { x1: "18", y1: "6", x2: "6", y2: "18" }
                    line { x1: "6", y1: "6", x2: "18", y2: "18" }
                },
                _ => rsx! {
                    circle { cx: "12", cy: "12", r: "9" }
                }
            }
        }
    }
}
