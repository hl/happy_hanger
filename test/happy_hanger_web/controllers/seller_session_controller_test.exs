defmodule HappyHangerWeb.SellerSessionControllerTest do
  use HappyHangerWeb.ConnCase

  import HappyHanger.SellersFixtures

  setup do
    %{seller: seller_fixture()}
  end

  describe "POST /sellers/log_in" do
    test "logs the seller in", %{conn: conn, seller: seller} do
      conn =
        post(conn, ~p"/sellers/log_in", %{
          "seller" => %{"email" => seller.email, "password" => valid_seller_password()}
        })

      assert get_session(conn, :seller_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ seller.email
      assert response =~ ~p"/sellers/settings"
      assert response =~ ~p"/sellers/log_out"
    end

    test "logs the seller in with remember me", %{conn: conn, seller: seller} do
      conn =
        post(conn, ~p"/sellers/log_in", %{
          "seller" => %{
            "email" => seller.email,
            "password" => valid_seller_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_happy_hanger_web_seller_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the seller in with return to", %{conn: conn, seller: seller} do
      conn =
        conn
        |> init_test_session(seller_return_to: "/foo/bar")
        |> post(~p"/sellers/log_in", %{
          "seller" => %{
            "email" => seller.email,
            "password" => valid_seller_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, seller: seller} do
      conn =
        conn
        |> post(~p"/sellers/log_in", %{
          "_action" => "registered",
          "seller" => %{
            "email" => seller.email,
            "password" => valid_seller_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, seller: seller} do
      conn =
        conn
        |> post(~p"/sellers/log_in", %{
          "_action" => "password_updated",
          "seller" => %{
            "email" => seller.email,
            "password" => valid_seller_password()
          }
        })

      assert redirected_to(conn) == ~p"/sellers/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/sellers/log_in", %{
          "seller" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/sellers/log_in"
    end
  end

  describe "DELETE /sellers/log_out" do
    test "logs the seller out", %{conn: conn, seller: seller} do
      conn = conn |> log_in_seller(seller) |> delete(~p"/sellers/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :seller_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the seller is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/sellers/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :seller_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
