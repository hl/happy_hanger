defmodule HappyHangerWeb.SellerSettingsLiveTest do
  use HappyHangerWeb.ConnCase

  alias HappyHanger.Sellers
  import Phoenix.LiveViewTest
  import HappyHanger.SellersFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_seller(seller_fixture())
        |> live(~p"/sellers/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if seller is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/sellers/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/sellers/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_seller_password()
      seller = seller_fixture(%{password: password})
      %{conn: log_in_seller(conn, seller), seller: seller, password: password}
    end

    test "updates the seller email", %{conn: conn, password: password, seller: seller} do
      new_email = unique_seller_email()

      {:ok, lv, _html} = live(conn, ~p"/sellers/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "seller" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Sellers.get_seller_by_email(seller.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "seller" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, seller: seller} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "seller" => %{"email" => seller.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_seller_password()
      seller = seller_fixture(%{password: password})
      %{conn: log_in_seller(conn, seller), seller: seller, password: password}
    end

    test "updates the seller password", %{conn: conn, seller: seller, password: password} do
      new_password = valid_seller_password()

      {:ok, lv, _html} = live(conn, ~p"/sellers/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "seller" => %{
            "email" => seller.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/sellers/settings"

      assert get_session(new_password_conn, :seller_token) != get_session(conn, :seller_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Sellers.get_seller_by_email_and_password(seller.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "seller" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sellers/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "seller" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      seller = seller_fixture()
      email = unique_seller_email()

      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_update_email_instructions(%{seller | email: email}, seller.email, url)
        end)

      %{conn: log_in_seller(conn, seller), token: token, email: email, seller: seller}
    end

    test "updates the seller email once", %{conn: conn, seller: seller, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/sellers/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/sellers/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Sellers.get_seller_by_email(seller.email)
      assert Sellers.get_seller_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/sellers/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/sellers/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, seller: seller} do
      {:error, redirect} = live(conn, ~p"/sellers/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/sellers/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Sellers.get_seller_by_email(seller.email)
    end

    test "redirects if seller is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/sellers/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/sellers/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
