import GLib from "gi://GLib";
import Gtk from "gi://Gtk?version=4.0";
import { createPoll } from "ags/time";

function YearCalendar() {
    const now = GLib.DateTime.new_now_local();
    let currentYear = now.get_year();

    const calendars: Gtk.Calendar[] = [];
    for (let i = 0; i < 12; i++) {
        const cal = new Gtk.Calendar({
            showDayNames: true,
            showHeading: true,
            showWeekNumbers: true,
        });
        calendars.push(cal);
    }

    const yearLabel = new Gtk.Label({
        label: currentYear.toString(),
        cssClasses: ["year-label"],
    });

    const updateCalendars = (year: number) => {
        currentYear = year;
        yearLabel.set_label(year.toString());
        for (let month = 0; month < 12; month++) {
            calendars[month].set_property("year", year);
            calendars[month].set_property("month", month);
        }
    };

    updateCalendars(currentYear);

    const grid = new Gtk.Grid({
        rowSpacing: 12,
        columnSpacing: 12,
        halign: Gtk.Align.CENTER,
    });

    calendars.forEach((cal, i) => {
        grid.attach(cal, i % 4, Math.floor(i / 4), 1, 1);
    });

    return (
        <Gtk.Box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={8}
            cssClasses={["year-calendar", "bordered"]}
        >
            <Gtk.Box
                orientation={Gtk.Orientation.HORIZONTAL}
                spacing={8}
                halign={Gtk.Align.CENTER}
            >
                <Gtk.Button
                    iconName="go-previous-symbolic"
                    onClicked={() => updateCalendars(currentYear - 1)}
                />
                {yearLabel}
                <Gtk.Button
                    iconName="go-next-symbolic"
                    onClicked={() => updateCalendars(currentYear + 1)}
                />
            </Gtk.Box>
            {grid}
        </Gtk.Box>
    );
}

export default function Clock() {
    const time = createPoll("", 1000, () => {
        return GLib.DateTime.new_now_local().format(
            " %a, %e %b \u00B7 %H:%M"
        )!;
    });

    return (
        <Gtk.MenuButton cssClasses={["clock-button"]}>
            <Gtk.Label label={time} />
            <Gtk.Popover>
                <YearCalendar />
            </Gtk.Popover>
        </Gtk.MenuButton>
    );
}
