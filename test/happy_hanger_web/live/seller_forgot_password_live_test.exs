defmodule HappyHangerWeb.SellerForgotPasswordLiveTest do
  use HappyHangerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HappyHanger.SellersFixtures

  alias HappyHanger.Sellers
  alias HappyHanger.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/sellers/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/sellers/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/sellers/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_seller(seller_fixture())
        |> live(~p"/sellers/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{seller: seller_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, seller: seller} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", seller: %{"email" => seller.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Sellers.SellerToken, seller_id: seller.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", seller: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Sellers.SellerToken) == []
    end
  end
end
