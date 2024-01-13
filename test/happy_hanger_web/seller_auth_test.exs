defmodule HappyHangerWeb.SellerAuthTest do
  use HappyHangerWeb.ConnCase

  alias Phoenix.LiveView
  alias HappyHanger.Sellers
  alias HappyHangerWeb.SellerAuth
  import HappyHanger.SellersFixtures

  @remember_me_cookie "_happy_hanger_web_seller_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, HappyHangerWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{seller: seller_fixture(), conn: conn}
  end

  describe "log_in_seller/3" do
    test "stores the seller token in the session", %{conn: conn, seller: seller} do
      conn = SellerAuth.log_in_seller(conn, seller)
      assert token = get_session(conn, :seller_token)
      assert get_session(conn, :live_socket_id) == "sellers_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Sellers.get_seller_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, seller: seller} do
      conn = conn |> put_session(:to_be_removed, "value") |> SellerAuth.log_in_seller(seller)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, seller: seller} do
      conn = conn |> put_session(:seller_return_to, "/hello") |> SellerAuth.log_in_seller(seller)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, seller: seller} do
      conn = conn |> fetch_cookies() |> SellerAuth.log_in_seller(seller, %{"remember_me" => "true"})
      assert get_session(conn, :seller_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :seller_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_seller/1" do
    test "erases session and cookies", %{conn: conn, seller: seller} do
      seller_token = Sellers.generate_seller_session_token(seller)

      conn =
        conn
        |> put_session(:seller_token, seller_token)
        |> put_req_cookie(@remember_me_cookie, seller_token)
        |> fetch_cookies()
        |> SellerAuth.log_out_seller()

      refute get_session(conn, :seller_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Sellers.get_seller_by_session_token(seller_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "sellers_sessions:abcdef-token"
      HappyHangerWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> SellerAuth.log_out_seller()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if seller is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> SellerAuth.log_out_seller()
      refute get_session(conn, :seller_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_seller/2" do
    test "authenticates seller from session", %{conn: conn, seller: seller} do
      seller_token = Sellers.generate_seller_session_token(seller)
      conn = conn |> put_session(:seller_token, seller_token) |> SellerAuth.fetch_current_seller([])
      assert conn.assigns.current_seller.id == seller.id
    end

    test "authenticates seller from cookies", %{conn: conn, seller: seller} do
      logged_in_conn =
        conn |> fetch_cookies() |> SellerAuth.log_in_seller(seller, %{"remember_me" => "true"})

      seller_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> SellerAuth.fetch_current_seller([])

      assert conn.assigns.current_seller.id == seller.id
      assert get_session(conn, :seller_token) == seller_token

      assert get_session(conn, :live_socket_id) ==
               "sellers_sessions:#{Base.url_encode64(seller_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, seller: seller} do
      _ = Sellers.generate_seller_session_token(seller)
      conn = SellerAuth.fetch_current_seller(conn, [])
      refute get_session(conn, :seller_token)
      refute conn.assigns.current_seller
    end
  end

  describe "on_mount: mount_current_seller" do
    test "assigns current_seller based on a valid seller_token", %{conn: conn, seller: seller} do
      seller_token = Sellers.generate_seller_session_token(seller)
      session = conn |> put_session(:seller_token, seller_token) |> get_session()

      {:cont, updated_socket} =
        SellerAuth.on_mount(:mount_current_seller, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_seller.id == seller.id
    end

    test "assigns nil to current_seller assign if there isn't a valid seller_token", %{conn: conn} do
      seller_token = "invalid_token"
      session = conn |> put_session(:seller_token, seller_token) |> get_session()

      {:cont, updated_socket} =
        SellerAuth.on_mount(:mount_current_seller, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_seller == nil
    end

    test "assigns nil to current_seller assign if there isn't a seller_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        SellerAuth.on_mount(:mount_current_seller, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_seller == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_seller based on a valid seller_token", %{conn: conn, seller: seller} do
      seller_token = Sellers.generate_seller_session_token(seller)
      session = conn |> put_session(:seller_token, seller_token) |> get_session()

      {:cont, updated_socket} =
        SellerAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_seller.id == seller.id
    end

    test "redirects to login page if there isn't a valid seller_token", %{conn: conn} do
      seller_token = "invalid_token"
      session = conn |> put_session(:seller_token, seller_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: HappyHangerWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = SellerAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_seller == nil
    end

    test "redirects to login page if there isn't a seller_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: HappyHangerWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = SellerAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_seller == nil
    end
  end

  describe "on_mount: :redirect_if_seller_is_authenticated" do
    test "redirects if there is an authenticated  seller ", %{conn: conn, seller: seller} do
      seller_token = Sellers.generate_seller_session_token(seller)
      session = conn |> put_session(:seller_token, seller_token) |> get_session()

      assert {:halt, _updated_socket} =
               SellerAuth.on_mount(
                 :redirect_if_seller_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated seller", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               SellerAuth.on_mount(
                 :redirect_if_seller_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_seller_is_authenticated/2" do
    test "redirects if seller is authenticated", %{conn: conn, seller: seller} do
      conn = conn |> assign(:current_seller, seller) |> SellerAuth.redirect_if_seller_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if seller is not authenticated", %{conn: conn} do
      conn = SellerAuth.redirect_if_seller_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_seller/2" do
    test "redirects if seller is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> SellerAuth.require_authenticated_seller([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/sellers/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> SellerAuth.require_authenticated_seller([])

      assert halted_conn.halted
      assert get_session(halted_conn, :seller_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> SellerAuth.require_authenticated_seller([])

      assert halted_conn.halted
      assert get_session(halted_conn, :seller_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> SellerAuth.require_authenticated_seller([])

      assert halted_conn.halted
      refute get_session(halted_conn, :seller_return_to)
    end

    test "does not redirect if seller is authenticated", %{conn: conn, seller: seller} do
      conn = conn |> assign(:current_seller, seller) |> SellerAuth.require_authenticated_seller([])
      refute conn.halted
      refute conn.status
    end
  end
end
