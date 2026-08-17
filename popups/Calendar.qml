import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: calendar

    // ============================================================
    // DATE STATE
    // ============================================================

    property date currentDate: new Date()

    property int displayedMonth: currentDate.getMonth()
    property int displayedYear: currentDate.getFullYear()

    property int selectedDay: currentDate.getDate()
    property int selectedMonth: currentDate.getMonth()
    property int selectedYear: currentDate.getFullYear()

    // ============================================================
    // DIMENSIONS
    // ============================================================

    implicitWidth: 220
    implicitHeight: 260

    // ============================================================
    // TODAY
    // ============================================================

    function getToday() {
        return new Date();
    }

    function isCurrentMonth() {
        const now = new Date();

        return (
            displayedMonth === now.getMonth() &&
            displayedYear === now.getFullYear()
        );
    }

    function isToday(day, month, year) {
        const now = new Date();

        return (
            day === now.getDate() &&
            month === now.getMonth() &&
            year === now.getFullYear()
        );
    }

    readonly property string monthName:
        Qt.locale().monthName(
            displayedMonth,
            Locale.LongFormat
        )

    // ============================================================
    // CALENDAR FUNCTIONS
    // ============================================================

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstDayOfMonth(year, month) {
        // JavaScript:
        // Sunday = 0
        // Convert to:
        // Monday = 0

        return (new Date(year, month, 1).getDay() + 6) % 7;
    }

    function previousMonth() {
        if (displayedMonth === 0) {
            displayedMonth = 11;
            displayedYear--;
        } else {
            displayedMonth--;
        }
    }

    function nextMonth() {
        if (displayedMonth === 11) {
            displayedMonth = 0;
            displayedYear++;
        } else {
            displayedMonth++;
        }
    }

    function goToToday() {
        const now = new Date();

        displayedMonth = now.getMonth();
        displayedYear = now.getFullYear();

        selectedDay = now.getDate();
        selectedMonth = now.getMonth();
        selectedYear = now.getFullYear();
    }

    function selectDate(day, month, year) {
        selectedDay = day;
        selectedMonth = month;
        selectedYear = year;
    }

    function isSelected(day, month, year) {
        return (
            day === selectedDay &&
            month === selectedMonth &&
            year === selectedYear
        );
    }

    // ============================================================
    // MAIN
    // ============================================================

    ColumnLayout {
        anchors.fill: parent

        spacing: 6

        // ========================================================
        // HEADER
        // ========================================================

        RowLayout {
            Layout.fillWidth: true

            spacing: 4

            // ----------------------------------------------------
            // MONTH
            // ----------------------------------------------------

            Text {
                text: calendar.monthName

                color: Colors.text

                font.family: Typography.firaCode
                font.pixelSize: Typography.md
                font.bold: true

                textFormat: Text.PlainText

                Layout.fillWidth: true
            }

            // ----------------------------------------------------
            // YEAR
            // ----------------------------------------------------

            Text {
                text: calendar.displayedYear

                color: Colors.subtext

                font.family: Typography.firaCode
                font.pixelSize: Typography.sm

                textFormat: Text.PlainText
            }

            // ----------------------------------------------------
            // PREVIOUS MONTH
            // ----------------------------------------------------

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                radius: 6

                color: previousMouse.containsMouse
                    ? Colors.surface
                    : "transparent"

                Text {
                    anchors.centerIn: parent

                    text: "󰁍"

                    color: Colors.text

                    font.pixelSize: 15

                    textFormat: Text.PlainText
                }

                MouseArea {
                    id: previousMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        calendar.previousMonth();
                    }
                }
            }

            // ----------------------------------------------------
            // NEXT MONTH
            // ----------------------------------------------------

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                radius: 6

                color: nextMouse.containsMouse
                    ? Colors.surface
                    : "transparent"

                Text {
                    anchors.centerIn: parent

                    text: "󰁔"

                    color: Colors.text

                    font.pixelSize: 15

                    textFormat: Text.PlainText
                }

                MouseArea {
                    id: nextMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        calendar.nextMonth();
                    }
                }
            }
        }

        // ========================================================
        // TODAY BUTTON
        // ========================================================

        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight: 24

            visible: !calendar.isCurrentMonth()

            radius: 6

            color: todayMouse.containsMouse
                ? Colors.surface
                : "transparent"

            Text {
                anchors.centerIn: parent

                text: "Today"

                color: Colors.blue

                font.family: Typography.firaCode
                font.pixelSize: Typography.xs
                font.bold: true

                textFormat: Text.PlainText
            }

            MouseArea {
                id: todayMouse

                anchors.fill: parent

                hoverEnabled: true

                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    calendar.goToToday();
                }
            }
        }

        // ========================================================
        // WEEKDAYS
        // ========================================================

        GridLayout {
            Layout.fillWidth: true

            columns: 7

            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: [
                    "MON",
                    "TUE",
                    "WED",
                    "THU",
                    "FRI",
                    "SAT",
                    "SUN"
                ]

                Text {
                    required property string modelData

                    text: modelData

                    color: Colors.subtext

                    font.family: Typography.firaCode
                    font.pixelSize: Typography.xs
                    font.bold: true

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    textFormat: Text.PlainText
                }
            }
        }

        // ========================================================
        // DAYS
        // ========================================================

        GridLayout {
            id: calendarGrid

            Layout.fillWidth: true
            Layout.fillHeight: true

            columns: 7

            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: 42

                Item {
                    id: dayCell

                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // ------------------------------------------------
                    // MONTH CALCULATIONS
                    // ------------------------------------------------

                    readonly property int firstDay:
                        calendar.firstDayOfMonth(
                            calendar.displayedYear,
                            calendar.displayedMonth
                        )

                    readonly property int daysCurrentMonth:
                        calendar.daysInMonth(
                            calendar.displayedYear,
                            calendar.displayedMonth
                        )

                    readonly property int rawDay:
                        index - firstDay + 1

                    readonly property bool previousMonthDay:
                        rawDay < 1

                    readonly property bool nextMonthDay:
                        rawDay > daysCurrentMonth

                    readonly property int actualDay:
                        previousMonthDay
                            ? calendar.daysInMonth(
                                calendar.displayedYear,
                                calendar.displayedMonth - 1
                              ) + rawDay
                            : nextMonthDay
                                ? rawDay - daysCurrentMonth
                                : rawDay

                    readonly property int actualMonth:
                        previousMonthDay
                            ? calendar.displayedMonth - 1
                            : nextMonthDay
                                ? calendar.displayedMonth + 1
                                : calendar.displayedMonth

                    readonly property int actualYear:
                        actualMonth < 0
                            ? calendar.displayedYear - 1
                            : actualMonth > 11
                                ? calendar.displayedYear + 1
                                : calendar.displayedYear

                    readonly property bool currentMonthDay:
                        !previousMonthDay && !nextMonthDay

                    // ------------------------------------------------
                    // STATE
                    // ------------------------------------------------

                    readonly property bool today:
                        calendar.isToday(
                            actualDay,
                            actualMonth,
                            actualYear
                        )

                    readonly property bool selected:
                        calendar.isSelected(
                            actualDay,
                            actualMonth,
                            actualYear
                        )

                    // ------------------------------------------------
                    // DAY
                    // ------------------------------------------------

                    Rectangle {
                        anchors.centerIn: parent

                        width: Math.min(
                            parent.width,
                            parent.height
                        )

                        height: width

                        radius: width / 2

                        // TODAY ALWAYS GETS PRIORITY
                        color: dayCell.today
                            ? Colors.text
                            : dayCell.selected
                                ? Colors.surface
                                : "transparent"

                        opacity: dayCell.currentMonthDay
                            ? 1
                            : 0.3

                        // ------------------------------------------------
                        // DAY NUMBER
                        // ------------------------------------------------

                        Text {
                            anchors.centerIn: parent

                            text: dayCell.actualDay

                            color: dayCell.today
                                ? Colors.base
                                : Colors.text

                            font.family: Typography.firaCode
                            font.pixelSize: Typography.xs

                            font.bold:
                                dayCell.today ||
                                dayCell.selected

                            textFormat: Text.PlainText
                        }

                        // ------------------------------------------------
                        // CLICK
                        // ------------------------------------------------

                        MouseArea {
                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                calendar.selectDate(
                                    dayCell.actualDay,
                                    dayCell.actualMonth,
                                    dayCell.actualYear
                                );
                            }
                        }
                    }
                }
            }
        }
    }
}