const LeafletMap = {
  mounted() {
    this.markers = {}
    this.circles = {}
    this.selectedMarker = null
    this.selectedCircle = null

    this.map = L.map(this.el, {
      center: [37.7749, -122.4194],
      zoom: 12
    })

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19
    }).addTo(this.map)

    // If interactive (not static), send click events to server
    if (this.el.dataset.interactive === "true") {
      this.map.on("click", (e) => {
        this.pushEvent("map_clicked", {lat: e.latlng.lat, lng: e.latlng.lng})
      })
    }

    // If static, disable all interaction
    if (this.el.dataset.static === "true") {
      this.map.dragging.disable()
      this.map.touchZoom.disable()
      this.map.doubleClickZoom.disable()
      this.map.scrollWheelZoom.disable()
      this.map.boxZoom.disable()
      this.map.keyboard.disable()
      if (this.map.tap) this.map.tap.disable()
    }

    // Server -> Client events
    this.handleEvent("update_locations", ({locations}) => {
      this._updateLocations(locations)
    })

    this.handleEvent("update_geofences", ({geofences}) => {
      this._updateGeofences(geofences)
    })

    this.handleEvent("set_selected_location", ({lat, lng, radius}) => {
      this._setSelectedLocation(lat, lng, radius)
    })

    this.handleEvent("fit_bounds", ({bounds}) => {
      if (bounds && bounds.length > 0) {
        this.map.fitBounds(bounds, {padding: [30, 30], maxZoom: 15})
      }
    })

    this.handleEvent("clear_selected", () => {
      this._clearSelected()
    })

    this.handleEvent("set_view", ({lat, lng, zoom}) => {
      this.map.setView([lat, lng], zoom)
    })

    // Force a resize after mount to handle container sizing
    setTimeout(() => this.map.invalidateSize(), 100)
  },

  _userColors: ["#e74c3c","#3498db","#2ecc71","#f39c12","#9b59b6","#1abc9c","#e67e22","#34495e"],

  _hashUserId(id) {
    let hash = 0
    for (let i = 0; i < id.length; i++) {
      hash = ((hash << 5) - hash) + id.charCodeAt(i)
      hash |= 0
    }
    return Math.abs(hash) % this._userColors.length
  },

  _createUserIcon(loc) {
    const initial = (loc.display_name || "?").charAt(0).toUpperCase()
    const color = this._userColors[this._hashUserId(loc.user_id)]
    const innerStyle = loc.avatar_url
      ? `background-image:url(${loc.avatar_url});background-size:cover;background-position:center;`
      : `background-color:${color};`
    const initialHtml = loc.avatar_url ? "" : `<span style="color:#fff;font-size:14px;font-weight:bold;">${initial}</span>`

    return L.divIcon({
      className: "",
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -18],
      html: `<div style="width:32px;height:32px;border-radius:50%;border:2px solid #fff;box-shadow:0 2px 4px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;${innerStyle}">${initialHtml}</div>`
    })
  },

  _updateLocations(locations) {
    const seen = new Set()

    locations.forEach((loc) => {
      seen.add(loc.user_id)

      if (this.markers[loc.user_id]) {
        this.markers[loc.user_id].setLatLng([loc.lat, loc.lng])
        this.markers[loc.user_id].setIcon(this._createUserIcon(loc))
        this.markers[loc.user_id].setPopupContent(
          `<strong>${loc.display_name}</strong><br>${loc.time_ago}`
        )
      } else {
        const marker = L.marker([loc.lat, loc.lng], {icon: this._createUserIcon(loc)})
          .addTo(this.map)
          .bindPopup(`<strong>${loc.display_name}</strong><br>${loc.time_ago}`)
        this.markers[loc.user_id] = marker
      }
    })

    // Remove stale markers
    Object.keys(this.markers).forEach((id) => {
      if (!seen.has(id)) {
        this.map.removeLayer(this.markers[id])
        delete this.markers[id]
      }
    })
  },

  _updateGeofences(geofences) {
    const seen = new Set()

    geofences.forEach((gf) => {
      seen.add(gf.id)

      if (this.circles[gf.id]) {
        this.circles[gf.id].setLatLng([gf.lat, gf.lng])
        this.circles[gf.id].setRadius(gf.radius)
      } else {
        const circle = L.circle([gf.lat, gf.lng], {
          radius: gf.radius,
          color: "#3b82f6",
          fillColor: "#3b82f6",
          fillOpacity: 0.1,
          weight: 2
        }).addTo(this.map)

        circle.bindTooltip(gf.name)
        circle.on("click", () => {
          this.pushEvent("geofence_clicked", {id: gf.id, group_id: gf.group_id})
        })

        this.circles[gf.id] = circle
      }
    })

    // Remove stale circles
    Object.keys(this.circles).forEach((id) => {
      if (!seen.has(id)) {
        this.map.removeLayer(this.circles[id])
        delete this.circles[id]
      }
    })
  },

  _setSelectedLocation(lat, lng, radius) {
    this._clearSelected()

    this.selectedMarker = L.marker([lat, lng]).addTo(this.map)
    this.selectedCircle = L.circle([lat, lng], {
      radius: radius,
      color: "#3b82f6",
      fillColor: "#3b82f6",
      fillOpacity: 0.1,
      weight: 2
    }).addTo(this.map)

    this.map.setView([lat, lng], this.map.getZoom())
  },

  _clearSelected() {
    if (this.selectedMarker) {
      this.map.removeLayer(this.selectedMarker)
      this.selectedMarker = null
    }
    if (this.selectedCircle) {
      this.map.removeLayer(this.selectedCircle)
      this.selectedCircle = null
    }
  },

  destroyed() {
    if (this.map) {
      this.map.remove()
    }
  }
}

export default LeafletMap
