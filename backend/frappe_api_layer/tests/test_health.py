from frappe_api_layer.api.health import ping


def test_ping_returns_ok():
    result = ping()
    assert result["status"] == "ok"
    assert result["service"] == "bude_api"
    assert "version" in result
    assert "timestamp" in result
