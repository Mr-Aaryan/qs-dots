import QtQuick
import QtQuick.Shapes

import "../../theme"

/*
 * A circular gauge: value in the middle, arc around it, caption
 * underneath.
 *
 * The arc starts at twelve o'clock and sweeps clockwise, which is the
 * reading order people expect from a dial. PathAngleArc measures
 * clockwise from three o'clock, hence the -90 start.
 */
Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    // 0..1. Values outside that range are clamped, not wrapped.
    property real fraction: 0

    // Centre of the ring, e.g. "47%" or "62°".
    property string value: "--"

    property string label: ""
    property string detail: ""

    property color tint: Colors.accent

    property int diameter: 84
    property int thickness: 7

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))

    implicitWidth: root.diameter
    implicitHeight: root.diameter + captionBlock.height + 8

    // ============================================================
    // RING
    // ============================================================

    Item {
        id: ring

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.diameter
        height: root.diameter

        Shape {
            anchors.fill: parent

            /*
             * The curve renderer antialiases without needing a
             * multisampled layer, which matters for a stroke this
             * thin at this size.
             */
            preferredRendererType: Shape.CurveRenderer

            // Track.
            ShapePath {
                strokeWidth: root.thickness
                strokeColor: Colors.surface
                fillColor: "transparent"

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2

                    radiusX: (root.diameter - root.thickness) / 2
                    radiusY: (root.diameter - root.thickness) / 2

                    startAngle: 0
                    sweepAngle: 360
                }
            }

            // Progress.
            ShapePath {
                strokeWidth: root.thickness
                strokeColor: root.tint
                fillColor: "transparent"

                /*
                 * Round caps read better at a glance, but they are
                 * drawn beyond the arc's ends -- at a sweep of zero
                 * they would leave a dot sitting at twelve o'clock
                 * reporting a value that is not there.
                 */
                capStyle: root.clamped > 0.005 ? ShapePath.RoundCap : ShapePath.FlatCap

                PathAngleArc {
                    id: progressArc

                    centerX: ring.width / 2
                    centerY: ring.height / 2

                    radiusX: (root.diameter - root.thickness) / 2
                    radiusY: (root.diameter - root.thickness) / 2

                    startAngle: -90

                    sweepAngle: root.clamped * 360

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent

            text: root.value

            color: Colors.text

            /*
             * Mono: these figures tick, and a proportional face would
             * shift the whole string sideways as digits change width.
             */
            font.family: Typography.mono
            font.pixelSize: Typography.lg
            font.weight: Typography.demiBold

            textFormat: Text.PlainText
        }
    }

    // ============================================================
    // CAPTION
    // ============================================================

    Column {
        id: captionBlock

        anchors.top: ring.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter

        width: parent.width

        spacing: 1

        Text {
            width: parent.width

            text: root.label

            color: Colors.text

            font.family: Typography.ui
            font.pixelSize: Typography.xs
            font.weight: Typography.medium

            horizontalAlignment: Text.AlignHCenter

            elide: Text.ElideRight

            textFormat: Text.PlainText
        }

        Text {
            width: parent.width

            text: root.detail

            color: Colors.subtext

            opacity: 0.75

            font.family: Typography.ui
            font.pixelSize: Typography.xs

            horizontalAlignment: Text.AlignHCenter

            elide: Text.ElideRight

            textFormat: Text.PlainText
        }
    }
}
