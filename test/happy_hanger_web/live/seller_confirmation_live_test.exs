defmodule HappyHangerWeb.SellerConfirmationLiveTest do
  use HappyHangerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HappyHanger.SellersFixtures

  alias HappyHanger.Sellers
  alias HappyHanger.Repo

  setup do
    %{seller: seller_fixture()}
  end

  describe "Confirm seller" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sellers/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, seller: seller} do
      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_confirmation_instructions(seller, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Seller confirmed successfully"

      assert Sellers.get_seller!(seller.id).confirmed_at
      refute get_session(conn, :seller_token)
      assert Repo.all(Sellers.SellerToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Seller confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_seller(seller)

      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, seller: seller} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Seller confirmation link is invalid or it has expired"

      refute Sellers.get_seller!(seller.id).confirmed_at
    end
  end
end
