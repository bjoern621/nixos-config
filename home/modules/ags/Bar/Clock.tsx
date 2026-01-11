import GLib from "gi://GLib";
import Gtk from "gi://Gtk?version=4.0";
import { createPoll } from "ags/time";

const DAY_NAMES = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
const MONTH_NAMES = [
    "Januar",
    "Februar",
    "März",
    "April",
    "Mai",
    "Juni",
    "Juli",
    "August",
    "September",
    "Oktober",
    "November",
    "Dezember",
];

function getWeekNumber(date: GLib.DateTime): number {
    return date.get_week_of_year();
}

function getDaysInMonth(year: number, month: number): number {
    return GLib.DateTime.new_local(year, month + 1, 1, 0, 0, 0)!
        .add_months(1)!
        .add_days(-1)!
        .get_day_of_month();
}

function getFirstDayOfMonth(year: number, month: number): number {
    const first = GLib.DateTime.new_local(year, month + 1, 1, 0, 0, 0)!;
    const dow = first.get_day_of_week();
    return dow;
}

function MonthCalendar({ year, month }: { year: number; month: number }) {
    const now = GLib.DateTime.new_now_local();
    const todayYear = now.get_year();
    const todayMonth = now.get_month() - 1;
    const todayDay = now.get_day_of_month();

    const daysInMonth = getDaysInMonth(year, month);
    const firstDayOfWeek = getFirstDayOfMonth(year, month);

    const prevMonth = month === 0 ? 11 : month - 1;
    const prevMonthYear = month === 0 ? year - 1 : year;
    const daysInPrevMonth = getDaysInMonth(prevMonthYear, prevMonth);

    const monthGrid = new Gtk.Grid({
        rowSpacing: 2,
        columnSpacing: 2,
        cssClasses: ["month-grid"],
    });

    const heading = new Gtk.Label({
        label: MONTH_NAMES[month],
        cssClasses: ["month-heading"],
        halign: Gtk.Align.CENTER,
    });
    monthGrid.attach(heading, 0, 0, 8, 1);

    monthGrid.attach(
        new Gtk.Label({ label: "", cssClasses: ["week-number"] }),
        0,
        1,
        1,
        1
    );
    for (let d = 0; d < 7; d++) {
        const dayLabel = new Gtk.Label({
            label: DAY_NAMES[d],
            cssClasses: ["day-name"],
            hexpand: true,
            vexpand: true,
        });
        monthGrid.attach(dayLabel, d + 1, 1, 1, 1);
    }

    const startOffset = firstDayOfWeek - 1;
    let day = 1;
    let nextMonthDay = 1;

    for (let row = 0; row < 6; row++) {
        const rowDays: {
            day: number;
            isOtherMonth: boolean;
            date: GLib.DateTime;
        }[] = [];

        for (let col = 0; col < 7; col++) {
            const cellIndex = row * 7 + col;

            if (cellIndex < startOffset) {
                const d = daysInPrevMonth - startOffset + cellIndex + 1;
                rowDays.push({
                    day: d,
                    isOtherMonth: true,
                    date: GLib.DateTime.new_local(
                        prevMonthYear,
                        prevMonth + 1,
                        d,
                        0,
                        0,
                        0
                    )!,
                });
            } else if (day <= daysInMonth) {
                rowDays.push({
                    day: day,
                    isOtherMonth: false,
                    date: GLib.DateTime.new_local(
                        year,
                        month + 1,
                        day,
                        0,
                        0,
                        0
                    )!,
                });
                day++;
            } else {
                const nextMonth = month === 11 ? 0 : month + 1;
                const nextMonthYear = month === 11 ? year + 1 : year;
                rowDays.push({
                    day: nextMonthDay,
                    isOtherMonth: true,
                    date: GLib.DateTime.new_local(
                        nextMonthYear,
                        nextMonth + 1,
                        nextMonthDay,
                        0,
                        0,
                        0
                    )!,
                });
                nextMonthDay++;
            }
        }

        const allOtherMonth = rowDays.every((d) => d.isOtherMonth);

        const weekNum = getWeekNumber(rowDays[0].date);
        const weekClasses = ["week-number"];
        if (allOtherMonth) {
            weekClasses.push("other-month");
        }
        const weekLabel = new Gtk.Label({
            label: weekNum.toString(),
            cssClasses: weekClasses,
            hexpand: true,
            vexpand: true,
        });
        monthGrid.attach(weekLabel, 0, row + 2, 1, 1);

        for (let col = 0; col < 7; col++) {
            const { day: d, isOtherMonth, date } = rowDays[col];
            const classes: string[] = ["day"];

            if (isOtherMonth) {
                classes.push("other-month");
            }

            const dateYear = date.get_year();
            const dateMonth = date.get_month() - 1;
            const dateDay = date.get_day_of_month();
            if (
                dateYear === todayYear &&
                dateMonth === todayMonth &&
                dateDay === todayDay
            ) {
                classes.push("today");
            }

            const dayLabel = new Gtk.Label({
                label: d.toString(),
                cssClasses: classes,
                hexpand: true,
                vexpand: true,
            });
            monthGrid.attach(dayLabel, col + 1, row + 2, 1, 1);
        }
    }

    return monthGrid;
}

function YearCalendar() {
    const now = GLib.DateTime.new_now_local();
    let currentYear = now.get_year();

    const monthGrids: Gtk.Grid[] = [];

    const yearLabel = new Gtk.Label({
        label: currentYear.toString(),
        cssClasses: ["year-label"],
    });

    const mainGrid = new Gtk.Grid({
        rowSpacing: 8,
        columnSpacing: 12,
        halign: Gtk.Align.CENTER,
    });

    const updateCalendars = (year: number) => {
        currentYear = year;
        yearLabel.set_label(year.toString());

        monthGrids.forEach((g) => mainGrid.remove(g));
        monthGrids.length = 0;

        for (let month = 0; month < 12; month++) {
            const monthGrid = MonthCalendar({ year, month });
            monthGrids.push(monthGrid);
            mainGrid.attach(monthGrid, month % 4, Math.floor(month / 4), 1, 1);
        }
    };

    updateCalendars(currentYear);

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
            {mainGrid}
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
