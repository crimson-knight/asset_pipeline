#if canImport(UIKit) && !os(watchOS)
import UIKit
import MapKit

/// Native MapKit service-area primitive. No credentials, location permission,
/// geocoding, pricing, network writes or persistence. Crystal validates every
/// changed draft and independently validates again before the save callback.
@objc(APSKPropertyMapView)
public final class APSKPropertyMapView: UIView, MKMapViewDelegate, UIGestureRecognizerDelegate {
    private struct Ring: Equatable {
        var id: String
        var points: [[Double]]
    }
    private struct Snapshot { var rings: [Ring]; var active: Int }
    private let map = MKMapView()
    private let content = UIStackView()
    private let status = UILabel()
    private let hint = UILabel()
    private let ringButton = UIButton(type: .system)
    private let pointButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let modes = UISegmentedControl(items: ["Draw", "Edit", "Pan"])
    private let imagery = UISegmentedControl(items: ["Satellite", "Hybrid"])
    private var rings = [Ring(id: "lawn", points: [])]
    private var active = 0
    private var selected: Int?
    private var history: [Snapshot] = []
    private var revision: Int64 = 0
    private var cameraRevision: Int64?
    private var draftToken: UInt64 = 0
    private var saveToken: UInt64 = 0
    private var overlays: [String: (signature: [Ring], polygon: MKPolygon)] = [:]
    private var editable = false
    private var didLoad = false
    private var address = ""
    private var lastReportedDraft: String?
    private var draftCallbackScheduled = false
    private var draftIsValid = false

    @objc public static func make() -> UIView { APSKPropertyMapView(frame: .zero) }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        backgroundColor = .systemBackground
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
        map.delegate = self
        map.mapType = .hybrid
        map.showsUserLocation = false
        map.showsScale = true
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.accessibilityIdentifier = "property-map"
        map.accessibilityLabel = "Property imagery. Approximate service area, not property boundaries."
        map.layer.cornerRadius = 12
        map.clipsToBounds = true
        map.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        map.setContentHuggingPriority(.defaultLow, for: .vertical)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        content.addArrangedSubview(map)
        status.font = .preferredFont(forTextStyle: .footnote)
        status.adjustsFontForContentSizeCategory = true
        status.numberOfLines = 0
        status.textColor = .label
        status.accessibilityIdentifier = "property-validation"
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.adjustsFontForContentSizeCategory = true
        hint.numberOfLines = 0
        hint.textColor = .label
        hint.accessibilityIdentifier = "property-instructions"
        imagery.selectedSegmentIndex = 1
        imagery.accessibilityLabel = "Imagery style"
        imagery.accessibilityIdentifier = "property-imagery"
        imagery.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        imagery.addTarget(self, action: #selector(changeImagery), for: .valueChanged)
        modes.selectedSegmentIndex = 0
        modes.accessibilityLabel = "Map editing mode"
        modes.accessibilityIdentifier = "property-mode"
        modes.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        modes.addTarget(self, action: #selector(changeMode), for: .valueChanged)
        configureButton(ringButton, title: "Lawn outline", id: "property-ring")
        configureButton(pointButton, title: "Point…", id: "property-point")
        configureButton(saveButton, title: "Use this outline", id: "property-save")
        configureButton(undoButton, title: "Undo", id: "property-undo")
        saveButton.configuration = .filled()
        saveButton.setTitle("Use this outline", for: .normal)
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undo), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func configureButton(_ button: UIButton, title: String, id: String) {
        button.setTitle(title, for: .normal)
        button.accessibilityLabel = title
        button.accessibilityIdentifier = id
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func row(_ views: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return row
    }

    /// Called for first mount and for keyed reuse. Initial draft is consumed
    /// ONCE. Only an explicit camera revision changes the camera thereafter.
    @objc public func configure(_ json: String, draftToken: UInt64, saveToken: UInt64) {
        guard let data = json.data(using: .utf8), data.count <= 150_000,
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        self.draftToken = draftToken
        self.saveToken = saveToken
        let incomingEditable = config["editable"] as? Bool ?? false
        if !didLoad {
            editable = incomingEditable
            address = String((config["address"] as? String ?? "").prefix(256))
            imagery.selectedSegmentIndex = config["imagery"] as? String == "satellite" ? 0 : 1
            map.mapType = imagery.selectedSegmentIndex == 0 ? .satellite : .hybrid
            if !address.isEmpty {
                let label = UILabel()
                label.font = .preferredFont(forTextStyle: .footnote)
                label.adjustsFontForContentSizeCategory = true
                label.numberOfLines = 2
                label.textColor = .label
                label.text = address
                label.accessibilityIdentifier = "property-address"
                content.insertArrangedSubview(label, at: 0)
            }
            if let initial = config["outline"] as? [String: Any] { load(initial) }
            if editable {
                content.addArrangedSubview(imagery)
                content.addArrangedSubview(row([ringButton, pointButton]))
                content.addArrangedSubview(modes)
                content.addArrangedSubview(hint)
                content.addArrangedSubview(status)
                let reset = UIButton(type: .system)
                configureButton(reset, title: "Reset…", id: "property-reset")
                reset.addTarget(self, action: #selector(resetRequested), for: .touchUpInside)
                content.addArrangedSubview(row([undoButton, reset, saveButton]))
            }
            didLoad = true
        } else if !editable, let initial = config["outline"] as? [String: Any] { load(initial) }
        let nextRevision = (config["camera_revision"] as? NSNumber)?.int64Value ?? 0
        if cameraRevision != nextRevision,
           let latitude = config["latitude"] as? Double, let longitude = config["longitude"] as? Double,
           latitude.isFinite, longitude.isFinite, abs(latitude) <= 85, abs(longitude) <= 180 {
            let span = min(1, max(0.0001, config["span"] as? Double ?? 0.002))
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)), animated: false)
            cameraRevision = nextRevision
        }
        refresh()
    }

    private func load(_ value: [String: Any]) {
        guard value["schema"] as? String == "ap.property-outline.v1",
              let geometry = value["geometry"] as? [String: Any],
              let coords = geometry["coordinates"] as? [[[Double]]],
              let ids = value["ring_ids"] as? [String], coords.count == ids.count,
              (1...17).contains(coords.count), coords.reduce(0, { $0 + $1.count }) <= 529 else { return }
        var parsed: [Ring] = []
        for (index, closed) in coords.enumerated() {
            guard closed.count >= 4, closed.first == closed.last,
                  closed.allSatisfy({ $0.count == 2 && $0[0].isFinite && $0[1].isFinite && abs($0[0]) <= 180 && abs($0[1]) <= 85 }) else { return }
            parsed.append(Ring(id: ids[index], points: Array(closed.dropLast())))
        }
        rings = parsed
        revision = (value["revision"] as? NSNumber)?.int64Value ?? 0
        imagery.selectedSegmentIndex = value["imagery"] as? String == "satellite" ? 0 : 1
        map.mapType = imagery.selectedSegmentIndex == 0 ? .satellite : .hybrid
    }

    private func payload() -> String {
        let value: [String: Any] = ["schema": "ap.property-outline.v1", "revision": revision,
            "source": "user_drawn_map", "imagery": imagery.selectedSegmentIndex == 0 ? "satellite" : "hybrid", "units": "m2",
            "ring_ids": rings.map(\.id), "geometry": ["type": "Polygon", "coordinates": rings.map { $0.points + ($0.points.first.map { [$0] } ?? []) }]]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    @objc public func setValidation(_ valid: Bool, message: String) {
        draftIsValid = valid
        saveButton.isEnabled = valid && saveToken != 0
        status.text = message
        status.accessibilityValue = valid ? "valid" : "invalid"
    }

    private func checkpoint() {
        history.append(Snapshot(rings: rings, active: active))
        if history.count > 64 { history.removeFirst() }
        if revision < Int64.max { revision += 1 }
    }

    private func refresh() {
        reconcileOverlays()
        map.removeAnnotations(map.annotations.filter { $0 is Vertex })
        if editable {
            for (index, point) in rings[active].points.enumerated() {
                map.addAnnotation(Vertex(point: point, index: index))
            }
        }
        undoButton.isEnabled = !history.isEmpty
        ringButton.setTitle(active == 0 ? "Lawn outline" : "Exclusion \(active)", for: .normal)
        ringButton.accessibilityValue = "\(rings[active].points.count) points"
        hint.text = modes.selectedSegmentIndex == 0 ? "Tap around the lawn or excluded area. Pinch to zoom. Approximate area, not a survey." : modes.selectedSegmentIndex == 1 ? "Tap a point, then tap its new position. Use Point for precise coordinates or removal." : "Pan and zoom without changing your outline."
        updateMenus()
        saveButton.isEnabled = draftIsValid && saveToken != 0
        if editable {
            let raw = payload()
            // A parent can rerender in on_draft_change. Suppress unchanged
            // values BEFORE callback dispatch, and let the initial mount finish
            // so that render has a retained root to reuse. Coalesce pending
            // drafts and use the current token if a parent rebound callbacks.
            if lastReportedDraft != raw {
                lastReportedDraft = raw
                draftIsValid = false
                saveButton.isEnabled = false
                if !draftCallbackScheduled {
                    draftCallbackScheduled = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.draftCallbackScheduled = false
                        if let latest = self.lastReportedDraft {
                            CallbackBridge.fireString(token: self.draftToken, value: latest)
                        }
                    }
                }
            }
        }
    }

    private func updateMenus() {
        var ringActions = rings.enumerated().map { index, _ in UIAction(title: index == 0 ? "Lawn outline" : "Exclusion \(index)", state: active == index ? .on : .off) { [weak self] _ in
            guard let self else { return }; self.active = index; self.selected = nil; self.refresh()
        } }
        ringActions.append(UIAction(title: "Add exclusion", attributes: rings.count >= 17 ? [.disabled] : []) { [weak self] _ in
            guard let self else { return }; self.checkpoint(); self.rings.append(Ring(id: "exclusion-" + UUID().uuidString.lowercased(), points: [])); self.active = self.rings.count - 1; self.selected = nil; self.modes.selectedSegmentIndex = 0; self.refresh()
        })
        if active > 0 { ringActions.append(UIAction(title: "Remove this exclusion", attributes: .destructive) { [weak self] _ in
            guard let self else { return }; self.checkpoint(); self.rings.remove(at: self.active); self.active = 0; self.selected = nil; self.refresh()
        }) }
        ringButton.menu = UIMenu(children: ringActions)
        ringButton.showsMenuAsPrimaryAction = true
        let count = rings[active].points.count
        var actions = [UIAction(title: "Add by coordinates") { [weak self] _ in self?.coordinates(edit: false) }]
        if count > 0 {
            actions += [UIAction(title: "Select next point") { [weak self] _ in
                guard let self else { return }; self.selected = ((self.selected ?? -1) + 1) % count; self.modes.selectedSegmentIndex = 1; self.refresh()
            }, UIAction(title: "Edit selected coordinates", attributes: selected == nil ? [.disabled] : []) { [weak self] _ in self?.coordinates(edit: true) }, UIAction(title: "Remove selected point", attributes: selected == nil ? [.disabled] : [.destructive]) { [weak self] _ in
                guard let self, let selected = self.selected else { return }; self.checkpoint(); self.rings[self.active].points.remove(at: selected); self.selected = nil; self.refresh()
            }]
        }
        pointButton.setTitle(selected.map { "Point \($0 + 1)…" } ?? "Point…", for: .normal)
        pointButton.accessibilityValue = selected.map { "Selected point \($0 + 1)" } ?? "No point selected"
        pointButton.menu = UIMenu(children: actions)
        pointButton.showsMenuAsPrimaryAction = true
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard editable, modes.selectedSegmentIndex != 2 else { return }
        let location = recognizer.location(in: map)
        let coordinate = map.convert(location, toCoordinateFrom: map)
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite, abs(coordinate.latitude) <= 85, abs(coordinate.longitude) <= 180 else { return }
        if modes.selectedSegmentIndex == 1 {
            if let nearest = rings[active].points.enumerated().min(by: { distance($0.element, location) < distance($1.element, location) }), distance(nearest.element, location) <= 30 {
                selected = nearest.offset
            } else if let selected { checkpoint(); rings[active].points[selected] = [coordinate.longitude, coordinate.latitude]; self.selected = nil }
        } else { add([coordinate.longitude, coordinate.latitude]) }
        refresh()
    }

    private func add(_ point: [Double]) {
        guard rings.reduce(0, { $0 + $1.points.count }) < 512 else { setValidation(false, message: "Use at most 512 points."); return }
        checkpoint(); rings[active].points.append(point); selected = nil
    }

    private func distance(_ point: [Double], _ location: CGPoint) -> CGFloat {
        let rendered = map.convert(CLLocationCoordinate2D(latitude: point[1], longitude: point[0]), toPointTo: map)
        return hypot(rendered.x - location.x, rendered.y - location.y)
    }

    @objc private func changeImagery() { map.mapType = imagery.selectedSegmentIndex == 0 ? .satellite : .hybrid; refresh() }
    @objc private func changeMode() { selected = nil; refresh() }
    @objc private func undo() { guard let previous = history.popLast() else { return }; rings = previous.rings; active = previous.active; selected = nil; if revision < Int64.max { revision += 1 }; refresh() }
    @objc private func save() { guard saveButton.isEnabled else { return }; endEditing(true); CallbackBridge.fireString(token: saveToken, value: payload()) }

    private func presenter() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder { if let controller = current as? UIViewController { return controller }; responder = current.next }
        return nil
    }

    @objc private func resetRequested() {
        let alert = UIAlertController(title: "Reset the outline?", message: "Remove the lawn outline and exclusions. You can undo this change.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset outline", style: .destructive) { [weak self] _ in
            guard let self else { return }; self.checkpoint(); self.rings = [Ring(id: "lawn", points: [])]; self.active = 0; self.selected = nil; self.refresh()
        })
        presenter()?.present(alert, animated: true)
    }

    private func coordinates(edit: Bool) {
        let point = edit ? selected.map { rings[active].points[$0] } : nil
        let alert = UIAlertController(title: edit ? "Edit point" : "Add point", message: "WGS84 decimal degrees. Use a minus sign for west or south. Not survey-grade.", preferredStyle: .alert)
        for (index, name) in ["Longitude", "Latitude"].enumerated() {
            alert.addTextField { field in
                field.placeholder = name
                field.accessibilityLabel = name
                field.accessibilityIdentifier = "property-" + name.lowercased()
                field.keyboardType = .numbersAndPunctuation
                field.text = point.map { String($0[index]) }
                field.autocorrectionType = .no
                let toolbar = UIToolbar(); toolbar.sizeToFit()
                toolbar.items = [UIBarButtonItem(title: "Previous", primaryAction: UIAction { [weak alert] _ in alert?.textFields?.first?.becomeFirstResponder() }), UIBarButtonItem(title: "Next", primaryAction: UIAction { [weak alert] _ in alert?.textFields?.last?.becomeFirstResponder() }), UIBarButtonItem(systemItem: .flexibleSpace), UIBarButtonItem(title: "Done", primaryAction: UIAction { [weak alert] _ in alert?.view.endEditing(true) })]
                field.inputAccessoryView = toolbar
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: edit ? "Move point" : "Add point", style: .default) { [weak self] _ in
            guard let self else { return }
            guard let fields = alert.textFields, let lon = Double((fields[0].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)), let lat = Double((fields[1].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)), lon.isFinite, lat.isFinite, abs(lon) <= 180, abs(lat) <= 85 else {
                self.setValidation(false, message: "Enter a finite longitude (−180 to 180) and latitude (−85 to 85)."); return
            }
            if edit, let selected = self.selected { self.checkpoint(); self.rings[self.active].points[selected] = [lon, lat] } else { self.add([lon, lat]) }
            self.refresh()
        })
        presenter()?.present(alert, animated: true)
    }

    private func reconcileOverlays() {
        var desired = Set<String>()
        for (index, ring) in rings.enumerated() where ring.points.count >= 3 {
            desired.insert(ring.id)
            let signature = index == 0 ? rings : [ring]
            if overlays[ring.id]?.signature == signature { continue }
            if let old = overlays[ring.id] { map.removeOverlay(old.polygon) }
            var points = ring.points.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
            let holes: [MKPolygon] = index == 0 ? rings.dropFirst().filter { $0.points.count >= 3 }.map { hole in
                var coordinates = hole.points.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                return MKPolygon(coordinates: &coordinates, count: coordinates.count)
            } : []
            let polygon = MKPolygon(coordinates: &points, count: points.count, interiorPolygons: holes)
            polygon.title = index == 0 ? "Lawn outline" : "Excluded area"
            overlays[ring.id] = (signature, polygon)
            map.addOverlay(polygon, level: .aboveRoads)
        }
        for key in Set(overlays.keys).subtracting(desired) { if let old = overlays.removeValue(forKey: key) { map.removeOverlay(old.polygon) } }
    }

    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.strokeColor = polygon.title == "Lawn outline" ? tintColor : .secondaryLabel
        renderer.fillColor = polygon.title == "Lawn outline" ? tintColor.withAlphaComponent(0.2) : UIColor.clear
        renderer.lineWidth = 3
        if polygon.title != "Lawn outline" { renderer.lineDashPattern = [5, 4] }
        return renderer
    }

    private final class Vertex: NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        let index: Int
        var title: String? { "Point \(index + 1)" }
        init(point: [Double], index: Int) { coordinate = CLLocationCoordinate2D(latitude: point[1], longitude: point[0]); self.index = index }
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let vertex = annotation as? Vertex else { return nil }
        let view = MKMarkerAnnotationView(annotation: vertex, reuseIdentifier: nil)
        view.markerTintColor = tintColor
        view.glyphText = String(vertex.index + 1)
        view.displayPriority = .required
        view.accessibilityLabel = "Point \(vertex.index + 1)"
        view.accessibilityValue = selected == vertex.index ? "Selected" : "Not selected"
        view.accessibilityIdentifier = "property-vertex-\(vertex.index)"
        view.canShowCallout = false
        return view
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}
#endif
